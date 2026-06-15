# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Entry point for Storable's save/destroy hooks. Persists the record's
    # canonical composition as an RM node graph with immutable-append
    # versioning: every save snapshots a fresh graph and appends a Version;
    # superseded heads keep their graphs but lose latest_version.
    class GraphPersister
      def self.persist(record)
        new(record).persist
      end

      def self.purge(record)
        new(record).purge
      end

      def initialize(record)
        @record = record
      end

      def persist
        ActiveRecord::Base.transaction do
          previous = head_composition
          composition = create_composition
          record_version(composition, previous)
          composition
        end
      end

      def purge
        compositions = Composition.where(owner_type: @record.class.name, owner_id: @record.id)
        composition_ids = compositions.ids
        versions = Version.where(composition_id: composition_ids)
        contribution_ids = versions.pluck(:contribution_id).compact

        DataValue.where(composition_id: composition_ids).delete_all
        Node.where(composition_id: composition_ids).delete_all
        versions.delete_all
        Contribution.where(id: contribution_ids).delete_all
        compositions.delete_all
      end

      private

      def create_composition
        builder = GraphBuilder.new(canonical_hash)
        composition = Composition.create!(
          builder.composition_attributes.merge(
            uid: @record.uid,
            owner: @record,
            ehr: materialize_ehr,
            context_start_time: @record.try(:composed_at)
          )
        )
        builder.build!(composition)
        composition
      end

      def canonical_hash
        if @record.respond_to?(:rm_composition) && @record.rm_composition
          @record.rm_composition
        else
          @record.to_rm_composition
        end
      end

      def head_composition
        Composition.latest.find_by(owner_type: @record.class.name, owner_id: @record.id)
      end

      def materialize_ehr
        ehr_id = @record.try(:ehr_id)
        return nil if ehr_id.nil? || ehr_id.to_s.empty?

        Ehr.find_or_create_by!(ehr_id: ehr_id)
      end

      def record_version(composition, previous)
        change_type = previous ? 'amendment' : 'creation'
        previous&.update_columns(latest_version: false)

        contribution = Contribution.record!(change_type, ehr: composition.ehr)
        Version.create!(
          versioned_object_uid: composition.uid,
          composition: composition,
          contribution: contribution,
          version_tree_id: next_version_tree_id(composition.uid)
        )
      end

      def next_version_tree_id(uid)
        (Version.of_object(uid).last&.version_tree_id.to_i + 1).to_s
      end
    end
  end
end

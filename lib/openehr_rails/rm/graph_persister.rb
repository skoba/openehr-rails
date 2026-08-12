# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Entry point for Storable's save/destroy hooks. Delegates the actual
    # graph + version + contribution write to CompositionCommitter (shared
    # with the openEHR REST API's COMPOSITION endpoint); this class's own
    # job is just deriving the commit's inputs from the scaffolded record.
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
        CompositionCommitter.commit(
          canonical_hash,
          uid: @record.uid,
          owner: @record,
          ehr: materialize_ehr,
          context_start_time: @record.try(:composed_at)
        )
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

      def canonical_hash
        if @record.respond_to?(:rm_composition) && @record.rm_composition
          @record.rm_composition
        else
          @record.to_rm_composition
        end
      end

      def materialize_ehr
        ehr_id = @record.try(:ehr_id)
        return nil if ehr_id.nil? || ehr_id.to_s.empty?

        Ehr.find_or_create_by!(ehr_id: ehr_id)
      end
    end
  end
end

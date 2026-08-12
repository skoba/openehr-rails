# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Commits a canonical composition hash to the RM graph with
    # immutable-append versioning: every commit snapshots a fresh graph and
    # appends a Version; a prior head (found by uid) keeps its graph but
    # loses latest_version. Shared by Storable's save hook (GraphPersister,
    # owner: the scaffolded record) and the openEHR REST API's COMPOSITION
    # endpoint (owner: nil, graph-only).
    class CompositionCommitter
      def self.commit(canonical_hash, uid:, ehr: nil, owner: nil, context_start_time: nil)
        new(canonical_hash, uid: uid, ehr: ehr, owner: owner, context_start_time: context_start_time).commit
      end

      def initialize(canonical_hash, uid:, ehr: nil, owner: nil, context_start_time: nil)
        @canonical_hash = canonical_hash
        @uid = uid
        @ehr = ehr
        @owner = owner
        @context_start_time = context_start_time
      end

      def commit
        ActiveRecord::Base.transaction do
          previous = head_composition
          composition = create_composition
          record_version(composition, previous)
          composition
        end
      end

      private

      def create_composition
        builder = GraphBuilder.new(@canonical_hash)
        composition = Composition.create!(
          builder.composition_attributes.merge(
            uid: @uid, owner: @owner, ehr: @ehr, context_start_time: @context_start_time
          )
        )
        builder.build!(composition)
        composition
      end

      def head_composition
        Composition.latest.find_by(uid: @uid)
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

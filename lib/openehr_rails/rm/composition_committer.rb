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

      # Logical delete (#81): appends a version of the current head whose
      # lifecycle_state is 523 (deleted), recorded by a 'deleted' Contribution.
      # The head stays latest_version; Composition.not_deleted leaves it out.
      def self.delete(uid:, ehr: nil)
        head = Composition.latest.find_by!(uid: uid)
        hash = head.to_canonical_hash
        # The hash carries the context (and its recorded start_time) when the
        # head has one (#121); the keyword is only for a head serialized without.
        start = hash['context'] ? nil : head.context_start_time
        new(hash, uid: uid, ehr: ehr || head.ehr, owner: head.owner,
                  context_start_time: start).commit(deleting: true)
      end

      def initialize(canonical_hash, uid:, ehr: nil, owner: nil, context_start_time: nil)
        @canonical_hash = canonical_hash
        @uid = uid
        @ehr = ehr
        @owner = owner
        @context_start_time = context_start_time
      end

      # A new commit must carry the mandatory date-times and the context's
      # setting (#121); a logical delete re-commits the stored head as it is.
      def commit(deleting: false)
        RequiredAttributes.check!(@canonical_hash, context_start_time: @context_start_time) unless deleting
        ActiveRecord::Base.transaction do
          previous = head_composition
          composition = create_composition
          record_version(composition, previous, deleting: deleting)
          composition
        end
      end

      private

      def create_composition
        builder = GraphBuilder.new(@canonical_hash)
        attributes = builder.composition_attributes.merge(uid: @uid, owner: @owner, ehr: @ehr)
        merge_context_start_time(attributes) if @context_start_time.present?
        composition = Composition.create!(attributes)
        builder.build!(composition)
        composition
      end

      # An explicit context_start_time wins over the hash's own
      # context.start_time. Storable passes the record's composed_at (a Time);
      # a String is a recorded value and is kept as written (#121), as the
      # hash's own start_time is.
      def merge_context_start_time(attributes)
        extra = (attributes[:extra] || {}).except(RecordedTimes::KEYS[:start_time])
        if @context_start_time.is_a?(String)
          attributes[:context_start_time] = PartialTemporal.instant(@context_start_time) ||
                                            Time.zone.parse(@context_start_time)
          extra = extra.merge(RecordedTimes.extra_columns(Composition, start_time: @context_start_time)
                                           .fetch(:extra, {}))
        else
          attributes[:context_start_time] = @context_start_time
        end
        attributes[:extra] = extra.presence if attributes.key?(:extra) || extra.present?
      end

      def head_composition
        Composition.latest.find_by(uid: @uid)
      end

      def record_version(composition, previous, deleting:)
        change_type = if deleting then 'deleted'
                      elsif previous then 'amendment'
                      else 'creation'
                      end
        previous&.update_columns(latest_version: false)

        contribution = Contribution.record!(change_type, ehr: composition.ehr)
        Version.create!(
          versioned_object_uid: composition.uid,
          composition: composition,
          contribution: contribution,
          version_tree_id: next_version_tree_id(composition.uid),
          lifecycle_state_code: deleting ? Version::LIFECYCLE_DELETED : Version::LIFECYCLE_COMPLETE
        )
      end

      def next_version_tree_id(uid)
        (Version.of_object(uid).last&.version_tree_id.to_i + 1).to_s
      end
    end
  end
end

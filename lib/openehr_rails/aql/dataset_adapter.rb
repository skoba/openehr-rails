# frozen_string_literal: true

require 'openehr/aql'

module OpenehrRails
  module Aql
    # Builds an OpenEHR::AQL::Dataset (the AQL engine's only input boundary)
    # out of the RM graph. Feeds it real OpenEHR::RM objects via
    # Rm::Composition#to_rm (RmObjectBuilder) rather than the rm_composition
    # JSON cache, because OpenEHR::RM::CompositionFactory.create_from_json
    # does not recursively convert array-valued attributes (content/events/
    # items) into RM objects -- see doc/HANDOFF_openehr_aql_create_from_json.md
    # and spec/openehr_rails/rm/create_from_json_roundtrip_spec.rb.
    class DatasetAdapter
      def self.build(ehr_scope: OpenehrRails::Rm::Ehr.all, composition_scope: OpenehrRails::Rm::Composition.latest)
        new(ehr_scope: ehr_scope, composition_scope: composition_scope).call
      end

      def initialize(ehr_scope:, composition_scope:)
        @ehr_scope = ehr_scope
        @composition_scope = composition_scope
      end

      # Dataset.new never iterates eagerly, so this stays lazy end to end:
      # constructing it issues no queries; each Enumerator::Lazy chain below
      # only runs when the caller actually walks #each_ehr.
      def call
        OpenEHR::AQL::Dataset.new(ehrs: ehr_records)
      end

      private

      def ehr_records
        linked = @ehr_scope.find_each.lazy.map do |ehr|
          { ehr_id: ehr.ehr_id, compositions: compositions_for(ehr_id: ehr.id).map(&:to_rm) }
        end
        unlinked = [{ ehr_id: nil, compositions: compositions_for(ehr_id: nil).map(&:to_rm) }]
        linked + unlinked.lazy
      end

      def compositions_for(ehr_id:)
        @composition_scope.where(ehr_id: ehr_id).find_each.lazy
      end
    end
  end
end

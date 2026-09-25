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
          { ehr_id: ehr.ehr_id, compositions: rm_compositions_for(ehr_id: ehr.id) }
        end
        unlinked = [{ ehr_id: nil, compositions: rm_compositions_for(ehr_id: nil) }]
        linked + unlinked.lazy
      end

      def rm_compositions_for(ehr_id:)
        @composition_scope.where(ehr_id: ehr_id).find_each.lazy.filter_map { |composition| materialize(composition) }
      end

      # One composition whose graph cannot be rebuilt (a node type outside
      # RmObjectBuilder::TYPE_CLASSES, or an RM constructor rejecting stored
      # data) must not take every query in the store down with it (#44):
      # warn, naming the composition and the cause, and leave it out. The
      # rest of the EHR stays queryable; the warning is the report.
      def materialize(composition)
        composition.to_rm
      rescue StandardError => e
        report_skip("openehr-rails AQL: skipping composition uid=#{composition.uid} (id=#{composition.id}): " \
                    "#{e.class}: #{e.message}")
        nil
      end

      def report_skip(message)
        logger = defined?(::Rails) && ::Rails.respond_to?(:logger) ? ::Rails.logger : nil
        logger ? logger.warn(message) : warn(message)
      end
    end
  end
end

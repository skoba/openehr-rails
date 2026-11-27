# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Search, read and create-target lookup for the FHIR Observation
    # endpoints, over both entry sources (#101): scaffolded models
    # ("<record id>-<slug>" ids, unchanged) and runtime records in the RM
    # graph ("c<uuid hex>-<entry index>" ids, see RuntimeRecord).
    class ObservationQuery
      # code: archetype id (or nil for all); subject: "Patient/<ehr_id>" or an ehr_id.
      def initialize(code: nil, subject: nil)
        @code = code.presence
        @ehr_id = subject.presence && subject.split('/').last
      end

      def search
        filter_by_code(model_observations + runtime_observations)
      end

      def self.find(id)
        runtime_id = RuntimeRecord.parse_id(id)
        runtime_id ? find_runtime(*runtime_id) : find_model(id)
      end

      # The model entry a POST creates into; a code that only a runtime
      # template has cannot be created (no model), answered as 422.
      def self.creatable_entry(code)
        entry = ResourceRegistry.find_by_code(code) # rubocop:disable Rails/DynamicFindBy -- registry lookup, not ActiveRecord
        raise Deserializer::UnmappedResource, "unknown code #{code.inspect}" unless entry
        if entry.runtime?
          raise Deserializer::UnmappedResource,
                "#{code} belongs to a runtime-registered template; there is no model to create into"
        end

        entry
      end

      def self.find_model(id)
        slug = id.split('-', 2).last
        entry = ResourceRegistry.find_by_slug(slug) # rubocop:disable Rails/DynamicFindBy -- registry lookup, not ActiveRecord
        return nil unless entry

        record = entry.model.find_by(id: id.split('-', 2).first)
        record && Serializer.new(record).observations.find { |o| o[:id] == id }
      end

      def self.find_runtime(uuid, index)
        return nil unless rm_available?

        composition = runtime_compositions.find_by(['uid = ? OR uid LIKE ?', uuid, "#{uuid}::%"])
        return nil unless composition

        entries = ResourceRegistry.runtime_entries.select do |entry|
          entry.template_id == composition.template_id && entry.index == index
        end
        RuntimeRecord.new(composition).observations(entries).first
      end

      def self.runtime_compositions
        OpenehrRails::Rm::Composition.latest.not_deleted.where(owner_type: nil)
      end

      def self.rm_available?
        defined?(OpenehrRails::Rm) && OpenehrRails::Rm.enabled?
      end

      private

      # The model path, as FhirController did before #101.
      def model_observations
        entries = if @code
                    [ResourceRegistry.model_entries.find { |entry| entry.archetype_id == @code }].compact
                  else
                    ResourceRegistry.model_entries
                  end
        records = entries.flat_map { |entry| scoped_records(entry) }.uniq
        records.flat_map { |record| Serializer.new(record).observations }
      end

      def scoped_records(entry)
        relation = entry.model.all
        relation = relation.where(ehr_id: @ehr_id) if @ehr_id
        relation.to_a
      end

      def runtime_observations
        return [] unless self.class.rm_available?

        entries = ResourceRegistry.runtime_entries
        entries = entries.select { |entry| entry.archetype_id == @code } if @code
        return [] if entries.empty?

        by_template = entries.group_by(&:template_id)
        runtime_scope(by_template.keys).flat_map do |composition|
          RuntimeRecord.new(composition).observations(by_template.fetch(composition.template_id, []))
        end
      end

      def runtime_scope(template_ids)
        scope = self.class.runtime_compositions.where(template_id: template_ids).includes(:ehr).order(:id)
        scope = scope.joins(:ehr).where(openehr_ehrs: { ehr_id: @ehr_id }) if @ehr_id
        scope
      end

      def filter_by_code(observations)
        return observations unless @code

        observations.select { |o| o[:code][:coding].first[:code] == @code }
      end
    end
  end
end

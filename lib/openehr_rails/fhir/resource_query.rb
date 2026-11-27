# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Search, read and create-target lookup for the FHIR resource endpoints
    # (#101, #104), over both entry sources: scaffolded models
    # ("<record id>-<slug>" ids) and runtime records in the RM graph
    # ("c<uuid hex>-<entry index>" ids, see RuntimeRecord).
    class ResourceQuery
      # resource_type: 'Observation', 'Condition', ...
      # archetype_id:  narrows to one archetype (Observation: the `code`
      #                parameter; Condition: `category`), or nil for all
      # subject:       "Patient/<ehr_id>" or an ehr_id
      def initialize(resource_type:, archetype_id: nil, subject: nil)
        @resource_type = resource_type
        @archetype_id = archetype_id.presence
        @ehr_id = subject.presence && subject.split('/').last
      end

      def search
        (model_resources + runtime_resources).select { |resource| resource[:resourceType] == @resource_type }
      end

      def self.find(id, resource_type:)
        runtime_id = RuntimeRecord.parse_id(id)
        resource = runtime_id ? find_runtime(*runtime_id) : find_model(id)
        resource if resource && resource[:resourceType] == resource_type
      end

      # The model entry a POST /fhir/Observation creates into. A code that
      # only a runtime template has cannot be created (no model), answered
      # as 422.
      def self.creatable_entry(code)
        entry = ResourceRegistry.find_by_code(code) # rubocop:disable Rails/DynamicFindBy -- registry lookup, not ActiveRecord
        raise Deserializer::UnmappedResource, "unknown code #{code.inspect}" unless entry
        if entry.runtime?
          raise Deserializer::UnmappedResource,
                "#{code} belongs to a runtime-registered template; there is no model to create into"
        end
        unless entry.resource_type == 'Observation'
          raise Deserializer::UnmappedResource,
                "#{code} is served as #{entry.resource_type}, not Observation; only Observation can be created"
        end

        entry
      end

      # POST /fhir/Observation: creates the model record the resource maps to
      # and returns the Observation built from it.
      def self.create(resource)
        code = resource.dig('code', 'coding', 0, 'code')
        entry = creatable_entry(code)
        record = entry.model.create!(Deserializer.new(entry.model, resource).attributes)
        Serializer.new(record).observations.find { |o| o[:code][:coding].first[:code] == code }
      end

      def self.find_model(id)
        slug = id.split('-', 2).last
        entry = ResourceRegistry.find_by_slug(slug) # rubocop:disable Rails/DynamicFindBy -- registry lookup, not ActiveRecord
        return nil unless entry

        record = entry.model.find_by(id: id.split('-', 2).first)
        record && Serializer.new(record).resources.find { |resource| resource[:id] == id }
      end

      def self.find_runtime(uuid, index)
        return nil unless rm_available?

        composition = runtime_compositions.find_by(['uid = ? OR uid LIKE ?', uuid, "#{uuid}::%"])
        return nil unless composition

        entries = ResourceRegistry.runtime_entries.select do |entry|
          entry.template_id == composition.template_id && entry.index == index
        end
        RuntimeRecord.new(composition).resources(entries).first
      end

      def self.runtime_compositions
        OpenehrRails::Rm::Composition.latest.not_deleted.where(owner_type: nil)
      end

      def self.rm_available?
        defined?(OpenehrRails::Rm) && OpenehrRails::Rm.enabled?
      end

      private

      # The model path: with an archetype, the first model entry for it (as
      # FhirController did before #101).
      def model_resources
        entries = if @archetype_id
                    [ResourceRegistry.model_entries.find { |entry| entry.archetype_id == @archetype_id }].compact
                  else
                    ResourceRegistry.model_entries
                  end
        records = entries.flat_map { |entry| scoped_records(entry) }.uniq
        resources = records.flat_map { |record| Serializer.new(record).resources }
        @archetype_id ? resources.select { |resource| archetype_of(resource) == @archetype_id } : resources
      end

      def scoped_records(entry)
        relation = entry.model.all
        relation = relation.where(ehr_id: @ehr_id) if @ehr_id
        relation.to_a
      end

      def runtime_resources
        return [] unless self.class.rm_available?

        entries = ResourceRegistry.runtime_entries
        entries = entries.select { |entry| entry.archetype_id == @archetype_id } if @archetype_id
        return [] if entries.empty?

        by_template = entries.group_by(&:template_id)
        runtime_scope(by_template.keys).flat_map do |composition|
          RuntimeRecord.new(composition).resources(by_template.fetch(composition.template_id, []))
        end
      end

      def runtime_scope(template_ids)
        scope = self.class.runtime_compositions.where(template_id: template_ids).includes(:ehr).order(:id)
        scope = scope.joins(:ehr).where(openehr_ehrs: { ehr_id: @ehr_id }) if @ehr_id
        scope
      end

      # The archetype coding sits on Observation.code, and on the mapping
      # table's :anchor element otherwise (Condition.category).
      def archetype_of(resource)
        anchor = resource[:code] if resource[:resourceType] == 'Observation'
        anchor ||= Array(resource[:category]).first
        anchor&.dig(:coding, 0, :code)
      end
    end
  end
end

# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Builds a minimal HL7 FHIR R5 CapabilityStatement from the registered
    # resources, served at GET /fhir/metadata.
    module CapabilityStatement
      FHIR_VERSION = '5.0.0'

      module_function

      def build(base_url: nil)
        {
          resourceType: 'CapabilityStatement',
          status: 'active',
          date: Time.now.utc.iso8601,
          kind: 'instance',
          fhirVersion: FHIR_VERSION,
          format: %w[application/fhir+json],
          software: { name: 'openehr-rails' },
          implementation: ({ description: 'openEHR-Rails FHIR facade', url: base_url }.compact),
          rest: [{
            mode: 'server',
            resource: resource_components
          }]
        }
      end

      # The search parameter that narrows a resource type to one archetype:
      # the element carrying the archetype coding (#104).
      def archetype_search_param(resource_type)
        resource_type == 'Observation' ? :code : :category
      end

      def resource_components
        ResourceRegistry.entries.select(&:servable?).group_by(&:resource_type).map do |resource_type, entries|
          {
            type: resource_type,
            profile: nil,
            supportedProfile: entries.map { |e| "urn:openehr:#{e.archetype_id}" }.uniq,
            interaction: interactions(resource_type),
            searchParam: [
              { name: archetype_search_param(resource_type).to_s, type: 'token' },
              { name: 'subject', type: 'reference' }
            ]
          }.compact
        end
      end

      # Only Observation can be created (#104).
      def interactions(resource_type)
        codes = %w[read search-type]
        codes << 'create' if resource_type == 'Observation'
        codes.map { |code| { code: code } }
      end
    end
  end
end

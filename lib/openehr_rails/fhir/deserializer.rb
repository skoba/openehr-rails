# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Converts an incoming HL7 FHIR R5 Observation into ActiveRecord
    # attributes for a Storable model. Saving the record then persists the
    # canonical openEHR RM composition (the FHIR-in / openEHR-stored path).
    class Deserializer
      class UnmappedResource < StandardError; end

      def initialize(model, observation)
        @model = model
        @observation = observation.respond_to?(:deep_stringify_keys) ? observation.deep_stringify_keys : observation
      end

      def attributes
        entry = lookup_entry
        attrs = {}
        attrs[:ehr_id] = subject_reference if subject_reference

        if entry.fields.size == 1 && !@observation.key?('component')
          attrs.merge!(field_value(entry.fields.first, @observation))
        else
          merge_components(entry, attrs)
        end
        attrs
      end

      private

      def lookup_entry
        code = primary_code(@observation['code'])
        entry = ResourceRegistry.entries_for(@model).find { |e| e.archetype_id == code }
        raise UnmappedResource, "no field maps to Observation.code #{code.inspect}" unless entry

        entry
      end

      def merge_components(entry, attrs)
        Array(@observation['component']).each do |component|
          code = primary_code(component['code'])
          field = entry.fields.find { |f| "#{f[:archetype_id]}##{f[:node_id]}" == code || f[:archetype_id] == code }
          next unless field

          attrs.merge!(field_value(field, component))
        end
      end

      def field_value(field, node)
        key = "value#{TypeMap.datatype_for(field[:rm_type]).camelize}"
        raw = node[key]
        return {} if raw.nil?

        { field[:name].to_sym => coerce(field, raw) }
      end

      def coerce(field, raw)
        case field[:rm_type]
        when 'DV_QUANTITY', 'DV_PROPORTION'
          raw.is_a?(Hash) ? raw['value'] : raw
        when 'DV_CODED_TEXT'
          raw.is_a?(Hash) ? raw.dig('coding', 0, 'code') : raw
        else
          raw
        end
      end

      def primary_code(codeable)
        return nil unless codeable.is_a?(Hash)

        codeable.dig('coding', 0, 'code')
      end

      def subject_reference
        ref = @observation.dig('subject', 'reference')
        ref&.split('/')&.last
      end
    end
  end
end

# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Serializes a stored record (one openEHR COMPOSITION) into one HL7
    # FHIR R5 Observation per archetype entry that has data. Single-leaf
    # entries use value[x]; multi-leaf entries use component[].
    class Serializer
      ARCHETYPE_SYSTEM = ResourceRegistry::ARCHETYPE_SYSTEM
      UCUM_SYSTEM = 'http://unitsofmeasure.org'

      def initialize(record)
        @record = record
      end

      def observations
        ResourceRegistry.entries_for(@record.class).filter_map do |entry|
          present = entry.fields.select { |field| @record.public_send(field[:name]) }
          next if present.empty?

          build_observation(entry, present)
        end
      end

      private

      def build_observation(entry, fields)
        observation = {
          resourceType: 'Observation',
          id: "#{@record.id}-#{entry.slug}",
          status: 'final',
          code: { coding: [{ system: ARCHETYPE_SYSTEM, code: entry.archetype_id }] }
        }
        observation[:subject] = { reference: "Patient/#{@record.ehr_id}" } if subject?
        observation[:effectiveDateTime] = @record.composed_at.iso8601 if @record.composed_at

        if fields.size == 1
          observation.merge!(value_entry(fields.first))
        else
          observation[:component] = fields.map { |field| component_entry(field) }
        end
        observation
      end

      def value_entry(field)
        { value_key(field) => fhir_value(field) }
      end

      def component_entry(field)
        {
          code: { coding: [{ system: ARCHETYPE_SYSTEM, code: "#{field[:archetype_id]}##{field[:node_id]}" }] },
          value_key(field) => fhir_value(field)
        }
      end

      def value_key(field)
        "value#{TypeMap.datatype_for(field[:rm_type]).camelize}".to_sym
      end

      def fhir_value(field)
        value = @record.public_send(field[:name])
        case field[:rm_type]
        when 'DV_QUANTITY'
          units = field_units(field)
          { value: value, unit: units, system: UCUM_SYSTEM, code: units }
        when 'DV_CODED_TEXT'
          { coding: [{ system: field[:terminology_id] || 'local', code: value,
                       display: field[:code_labels]&.fetch(value, value) }] }
        when 'DV_COUNT'
          value.to_i
        when 'DV_BOOLEAN'
          value
        else
          value.to_s
        end
      end

      def field_units(field)
        units_attribute = "#{field[:name]}_units"
        (@record.respond_to?(units_attribute) && @record.public_send(units_attribute)) || field[:units]
      end

      def subject?
        @record.respond_to?(:ehr_id) && @record.ehr_id.present?
      end
    end
  end
end

# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Builds one HL7 FHIR R5 Observation for one archetype entry from plain
    # values, independent of where the record lives (#101): a scaffolded
    # Storable model (Serializer) or a composition in the RM graph
    # (RuntimeRecord). Single-leaf entries use value[x]; multi-leaf entries
    # use component[].
    #
    #   entry          - ResourceRegistry::Entry (archetype_id, fields)
    #   values         - {field name => value}; a field is "present" when its
    #                    value is truthy (as before #101)
    #   units          - {field name => unit} overriding the field's own :units
    #   id             - the resource id
    #   subject_ehr_id - becomes subject Patient/<ehr_id> when present
    #   effective_at   - Time for effectiveDateTime, or nil
    class ResourceBuilder
      ARCHETYPE_SYSTEM = ResourceRegistry::ARCHETYPE_SYSTEM
      UCUM_SYSTEM = 'http://unitsofmeasure.org'

      def initialize(entry, values:, id:, units: {}, subject_ehr_id: nil, effective_at: nil)
        @entry = entry
        @values = values
        @units = units
        @id = id
        @subject_ehr_id = subject_ehr_id
        @effective_at = effective_at
      end

      # nil when no field of the entry has a value.
      def build
        fields = @entry.fields.select { |field| @values[field[:name]] }
        return nil if fields.empty?

        observation = {
          resourceType: 'Observation',
          id: @id,
          status: 'final',
          code: { coding: [{ system: ARCHETYPE_SYSTEM, code: @entry.archetype_id }] }
        }
        observation[:subject] = { reference: "Patient/#{@subject_ehr_id}" } if @subject_ehr_id.present?
        observation[:effectiveDateTime] = @effective_at.iso8601 if @effective_at

        if fields.size == 1
          observation.merge!(value_entry(fields.first))
        else
          observation[:component] = fields.map { |field| component_entry(field) }
        end
        observation
      end

      private

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
        :"value#{TypeMap.datatype_for(field[:rm_type]).camelize}"
      end

      def fhir_value(field)
        value = @values[field[:name]]
        case field[:rm_type]
        when 'DV_QUANTITY'
          units = @units[field[:name]] || field[:units]
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
    end
  end
end

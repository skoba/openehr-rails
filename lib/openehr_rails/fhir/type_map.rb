# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Static mapping from openEHR Reference Model types to HL7 FHIR R5.
    # Drives both StructureDefinition generation (M2) and the REST
    # serializer/deserializer (M3).
    module TypeMap
      FHIR_BASE_URL = 'http://hl7.org/fhir/StructureDefinition'

      # openEHR ENTRY type => FHIR R5 resource type.
      ENTRY_RESOURCES = {
        'OBSERVATION' => 'Observation',
        'EVALUATION' => 'Condition',
        'INSTRUCTION' => 'ServiceRequest',
        'ACTION' => 'Procedure',
        'ADMIN_ENTRY' => 'Encounter'
      }.freeze

      # openEHR data value type => FHIR R5 element type (value[x] suffix /
      # datatype name) used in StructureDefinition element constraints.
      DATA_VALUE_TYPES = {
        'DV_QUANTITY' => 'Quantity',
        'DV_COUNT' => 'integer',
        'DV_PROPORTION' => 'Ratio',
        'DV_ORDINAL' => 'CodeableConcept',
        'DV_TEXT' => 'string',
        'DV_CODED_TEXT' => 'CodeableConcept',
        'DV_IDENTIFIER' => 'Identifier',
        'DV_URI' => 'url',
        'DV_BOOLEAN' => 'boolean',
        'DV_DATE' => 'date',
        'DV_TIME' => 'time',
        'DV_DATE_TIME' => 'dateTime',
        'DV_DURATION' => 'Duration',
        'DV_MULTIMEDIA' => 'Attachment'
      }.freeze

      module_function

      def resource_for_entry(rm_type)
        ENTRY_RESOURCES.fetch(rm_type, 'Observation')
      end

      def datatype_for(rm_type)
        DATA_VALUE_TYPES.fetch(rm_type, 'string')
      end

      def base_definition_for_entry(rm_type)
        "#{FHIR_BASE_URL}/#{resource_for_entry(rm_type)}"
      end

      # Element on the base resource whose value an openEHR leaf maps to.
      # Single-leaf Observations use value[x]; everything else hangs off a
      # component (handled by the profile/serializer per resource).
      def value_element(resource_type)
        resource_type == 'Observation' ? 'value[x]' : 'value[x]'
      end
    end
  end
end

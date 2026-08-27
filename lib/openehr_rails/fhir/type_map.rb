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

      # Leaf-level mapping for archetypes whose base FHIR resource has no
      # `component` slot, so a multi-leaf entry cannot hang off one. Keyed by
      # archetype id; `docs/design/multi-leaf-non-observation-plan.md` section 8
      # is the normative table, with one rationale line per element.
      #
      # Both ProfileGenerator (JSON facade) and FshGenerator generate from here,
      # so neither can carry a mapping decision the other lacks -- the two-copies
      # drift that produced skoba/openehr-rails#33 in the first place.
      #
      # :anchor    - element carrying the fixed archetype coding. For Condition
      #              this is `category`, not `code`: under a proper mapping
      #              `code` is the diagnosis itself (at0002).
      # :element   - FSH path for the leaf.
      # :sd_path   - StructureDefinition path when it differs from the FSH one
      #              (FHIR names choice elements `onset[x]`, FSH `onsetDateTime`).
      # :bind_value_set - bind the leaf's own C_CODE_REFERENCE value set here.
      #              Absent means "do not bind" -- e.g. Condition.verificationStatus
      #              already carries a required binding to condition-ver-status,
      #              so an archetype's local at-codes must not be bound to it.
      ENTRY_ELEMENT_MAPS = {
        'openEHR-EHR-EVALUATION.problem_diagnosis.v1' => {
          anchor: 'category',
          leaves: {
            'at0002' => { element: 'code', bind_value_set: true },
            'at0077' => { element: 'onsetDateTime', sd_path: 'onset[x]' },
            'at0003' => { element: 'recordedDate' },
            'at0030' => { element: 'abatementDateTime', sd_path: 'abatement[x]' },
            'at0073' => { element: 'verificationStatus' }
          }.freeze
        }.freeze
      }.freeze

      module_function

      def element_map_for(archetype_id)
        ENTRY_ELEMENT_MAPS[archetype_id]
      end

      # OPT writes C_CODE_REFERENCE value sets as `terminology:<canonical>`;
      # a FHIR binding target is the canonical itself.
      def value_set_canonical(uri)
        uri.to_s.delete_prefix('terminology:')
      end

      def resource_for_entry(rm_type)
        ENTRY_RESOURCES.fetch(rm_type, 'Observation')
      end

      def datatype_for(rm_type)
        DATA_VALUE_TYPES.fetch(rm_type, 'string')
      end

      def base_definition_for_entry(rm_type)
        "#{FHIR_BASE_URL}/#{resource_for_entry(rm_type)}"
      end
    end
  end
end

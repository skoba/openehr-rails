# frozen_string_literal: true

require 'json'
require 'active_support/core_ext/string'

module OpenehrRails
  module Fhir
    # Generates HL7 FHIR R5 StructureDefinition profiles (as plain Hashes /
    # JSON) from an openEHR Operational Template. One profile per ENTRY:
    # the entry's RM type selects the base FHIR resource, and the leaf
    # ELEMENTs constrain value[x] (single leaf) or component slices (many).
    class ProfileGenerator
      FHIR_VERSION = '5.0.0'
      ARCHETYPE_SYSTEM = 'http://openehr.org/ckm/archetypes'
      UCUM_SYSTEM = 'http://unitsofmeasure.org'
      CANONICAL_BASE = 'urn:openehr'

      def initialize(template)
        @template = template
        @entries = OpenehrRails::Opt::FieldExtractor.new(template).entries
      end

      def profiles
        @entries.map { |entry| build_profile(entry) }
      end

      def to_json_files
        profiles.to_h { |profile| [profile[:id], JSON.pretty_generate(profile)] }
      end

      private

      def build_profile(entry)
        resource_type = TypeMap.resource_for_entry(entry[:rm_type])
        {
          resourceType: 'StructureDefinition',
          id: profile_id(entry[:archetype_id]),
          url: "#{CANONICAL_BASE}:#{entry[:archetype_id]}",
          name: entry[:concept].camelize,
          title: "openEHR #{entry[:concept].humanize} (#{entry[:archetype_id]})",
          status: 'draft',
          fhirVersion: FHIR_VERSION,
          kind: 'resource',
          abstract: false,
          type: resource_type,
          baseDefinition: TypeMap.base_definition_for_entry(entry[:rm_type]),
          derivation: 'constraint',
          differential: { element: differential_elements(entry, resource_type) }
        }
      end

      def differential_elements(entry, resource_type)
        elements = [code_element(resource_type, entry[:archetype_id])]
        if entry[:fields].size == 1
          elements.concat(value_elements(resource_type, entry[:fields].first))
        else
          elements.concat(component_elements(resource_type, entry[:fields]))
        end
        elements
      end

      def code_element(resource_type, archetype_id)
        {
          path: "#{resource_type}.code",
          patternCodeableConcept: {
            coding: [{ system: ARCHETYPE_SYSTEM, code: archetype_id }]
          }
        }
      end

      def value_elements(resource_type, field)
        path = "#{resource_type}.value[x]"
        element = {
          path: path,
          min: field[:required] ? 1 : 0,
          type: [{ code: TypeMap.datatype_for(field[:rm_type]) }]
        }
        apply_value_constraints(element, field)
        [element]
      end

      def component_elements(resource_type, fields)
        slice_root = {
          path: "#{resource_type}.component",
          slicing: {
            discriminator: [{ type: 'pattern', path: 'code' }],
            rules: 'open'
          }
        }
        slices = fields.flat_map { |field| component_slice(resource_type, field) }
        [slice_root, *slices]
      end

      def component_slice(resource_type, field)
        slice_name = field[:name].dasherize
        code_path = {
          path: "#{resource_type}.component",
          sliceName: slice_name,
          min: field[:required] ? 1 : 0
        }
        code_constraint = {
          path: "#{resource_type}.component.code",
          patternCodeableConcept: {
            coding: [{ system: ARCHETYPE_SYSTEM, code: "#{field[:archetype_id]}##{field[:node_id]}" }]
          }
        }
        value_constraint = {
          path: "#{resource_type}.component.value[x]",
          type: [{ code: TypeMap.datatype_for(field[:rm_type]) }]
        }
        apply_value_constraints(value_constraint, field)
        [code_path, code_constraint, value_constraint]
      end

      def apply_value_constraints(element, field)
        case field[:rm_type]
        when 'DV_QUANTITY'
          return unless field[:units]

          element[:patternQuantity] = {
            unit: field[:units],
            system: UCUM_SYSTEM,
            code: field[:units]
          }
        when 'DV_CODED_TEXT'
          return if field[:code_list].nil? || field[:code_list].empty?

          element[:binding] = { strength: 'required' }
        end
      end

      def profile_id(archetype_id)
        "openehr-#{archetype_id.delete_prefix('openEHR-EHR-').parameterize.dasherize}"
      end
    end
  end
end

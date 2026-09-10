# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Raised for an ENTRY that has more than one leaf, maps to a FHIR resource
    # without a `component` element (anything but Observation), and has no row
    # in TypeMap::ENTRY_ELEMENT_MAPS -- nothing valid can be generated for it
    # (skoba/openehr-rails#33 ruling, docs/design/multi-leaf-non-observation-plan.md
    # section 9.3). ProfileGenerator and FshGenerator rescue this per entry,
    # skip the entry and expose the error through #skipped; a caller that wants
    # a hard failure re-raises from there.
    class UnsupportedProfileError < StandardError
      attr_reader :archetype_id, :resource_type, :leaf_count

      def initialize(archetype_id, resource_type, leaf_count)
        @archetype_id = archetype_id
        @resource_type = resource_type
        @leaf_count = leaf_count
        super(
          "#{archetype_id}: #{leaf_count} leaves map to #{resource_type}, which has no " \
          'component element, and TypeMap::ENTRY_ELEMENT_MAPS has no row for this ' \
          'archetype -- skipped (skoba/openehr-rails#33, #35)'
        )
      end
    end
  end
end

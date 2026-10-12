# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Raised for an ENTRY that maps to a FHIR resource other than Observation --
    # which has neither `value[x]` (single leaf) nor `component` (several) --
    # and has no row in TypeMap::ENTRY_ELEMENT_MAPS: nothing valid can be
    # generated for it (skoba/openehr-rails#33 ruling and #38,
    # docs/design/multi-leaf-non-observation-plan.md sections 9.3 and 9.7).
    # ProfileGenerator and FshGenerator rescue this per entry, skip the entry
    # and expose the error through #skipped; a caller that wants a hard failure
    # re-raises from there.
    class UnsupportedProfileError < StandardError
      attr_reader :archetype_id, :resource_type, :leaf_count

      def initialize(archetype_id, resource_type, leaf_count)
        @archetype_id = archetype_id
        @resource_type = resource_type
        @leaf_count = leaf_count
        super(leaf_count.zero? ? no_leaves_message : unmapped_message)
      end

      private

      # 0 leaves: FieldExtractor found no ELEMENT under the entry (today that
      # includes every INSTRUCTION, #47), so there is nothing to profile.
      def no_leaves_message
        "#{archetype_id} (#{resource_type}): the entry has no leaves, nothing to profile -- skipped " \
          '(skoba/openehr-rails#49; INSTRUCTION leaves: #47)'
      end

      def unmapped_message
        "#{archetype_id}: #{leaf_count} #{leaf_count == 1 ? 'leaf maps' : 'leaves map'} to " \
          "#{resource_type}, which has neither value[x] nor component, and " \
          'TypeMap::ENTRY_ELEMENT_MAPS has no row for this archetype -- skipped ' \
          '(skoba/openehr-rails#33, #38; mapping rows: #35, #37)'
      end
    end
  end
end

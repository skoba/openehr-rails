# frozen_string_literal: true

module OpenehrRails
  # The part of Storable that places fields in their root instances: one entry
  # per entry instance, one archetyped node per embedded-root instance
  # (skoba/openehr-rails#61).
  module Storable
    ARCHETYPE_ID_SEGMENT = /\A[^.-]+-[^.-]+-[A-Z_]+\.[^.]+\.v\d/

    # The field's root instances from its entry down ([[root_path, ordinal], ...]).
    # FIELD_MAPs generated before root_chain (0.9.0 to 0.11.0) get one derived
    # from the [archetype_id] segments of the path, every ordinal 0; the shape
    # guard refuses the repeated roots that derivation cannot place.
    def self.root_chain(field)
      return field[:root_chain] if field[:root_chain]

      prefix = +''
      path_segments(field[:path]).each_with_object([]) do |(attribute, node_id), chain|
        prefix << "/#{attribute}#{"[#{node_id}]" if node_id}"
        next unless node_id&.match?(ARCHETYPE_ID_SEGMENT) && node_id.exclude?('-SECTION.')

        chain << [prefix.dup, 0]
      end
    end

    private

    def new_entry(field, entry_path)
      archetype_id = OpenehrRails::Storable.path_segments(entry_path).last.last
      {
        '_type' => field[:entry_rm_type],
        'archetype_node_id' => archetype_id,
        'archetype_details' => archetype_details(archetype_id)
      }
    end

    def new_root_node(attribute, parent_type, archetype_id)
      new_rm_node(attribute, parent_type, archetype_id).merge('archetype_details' => archetype_details(archetype_id))
    end

    def archetype_details(archetype_id)
      { '_type' => 'ARCHETYPED', 'archetype_id' => { 'value' => archetype_id }, 'rm_version' => '1.0.4' }
    end
  end
end

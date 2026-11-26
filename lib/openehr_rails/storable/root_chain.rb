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

    # Appends a new entry for +entry_path+ to +content+, inside the SECTION
    # nodes its path names (one per section path, created on first use, #62).
    def place_entry(content, section_nodes, field, entry_path)
      container = content
      prefix = ''
      OpenehrRails::Storable.path_segments(entry_path)[0...-1].each do |attribute, section_id|
        prefix += "/#{attribute}[#{section_id}]"
        section = section_nodes[prefix] ||= (container << new_section(section_id)).last
        container = section['items'] ||= []
      end
      (container << new_entry(field, entry_path)).last
    end

    def new_section(section_id)
      section = { '_type' => 'SECTION', 'archetype_node_id' => section_id }
      section['archetype_details'] = archetype_details(section_id) if section_id.match?(ARCHETYPE_ID_SEGMENT)
      section
    end

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

    # Infers the RM type of an intermediate node from the attribute it
    # fills and the parent's type. 'items' children stay untyped here: the
    # 'value' branch marks ELEMENTs and the 'items' descent marks CLUSTERs.
    def new_rm_node(attribute, parent_type, node_id)
      rm_type =
        case attribute
        when 'data'
          parent_type == 'OBSERVATION' ? 'HISTORY' : 'ITEM_TREE'
        when 'events' then 'POINT_EVENT'
        when 'state', 'protocol', 'description' then 'ITEM_TREE'
        when 'activities' then 'ACTIVITY'
        end
      node = {}
      node['_type'] = rm_type if rm_type
      node['archetype_node_id'] = node_id
      node
    end

    def archetype_details(archetype_id)
      { '_type' => 'ARCHETYPED', 'archetype_id' => { 'value' => archetype_id }, 'rm_version' => '1.0.4' }
    end
  end
end

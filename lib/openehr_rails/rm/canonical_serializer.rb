# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Serializes a stored composition graph back into the canonical
    # composition hash. Contract: for a graph built by GraphBuilder from
    # Storable#to_rm_composition output, the result is deep-equal to that
    # input (the JSON cache can always be regenerated from the graph).
    class CanonicalSerializer
      MULTIPLE_ATTRIBUTES = OpenehrRails::Storable::MULTIPLE_ATTRIBUTES

      def initialize(composition)
        @composition = composition
      end

      def call
        hash = {
          '_type' => 'COMPOSITION',
          'archetype_node_id' => @composition.archetype_node_id,
          'archetype_details' => {
            '_type' => 'ARCHETYPED',
            'archetype_id' => { 'value' => @composition.archetype_node_id },
            'template_id' => { 'value' => @composition.template_id },
            'rm_version' => @composition.rm_version
          },
          'content' => @composition.content_nodes.map { |node| serialize_node(node) }
        }
        hash['name'] = { '_type' => 'DV_TEXT', 'value' => @composition.name_value } if @composition.name_value
        hash['uid'] = { '_type' => 'HIER_OBJECT_ID', 'value' => @composition.uid } if @composition.uid
        hash
      end

      private

      def serialize_node(node)
        hash = { '_type' => node.rm_type, 'archetype_node_id' => node.archetype_node_id }
        if node.archetype_id
          hash['archetype_details'] = {
            '_type' => 'ARCHETYPED',
            'archetype_id' => { 'value' => node.archetype_id },
            'rm_version' => '1.0.4'
          }
        end
        hash['name'] = { '_type' => 'DV_TEXT', 'value' => node.name_value } if node.name_value
        merge_special_attributes(hash, node)
        merge_children(hash, node)
        merge_data_values(hash, node)
        hash
      end

      def merge_special_attributes(hash, node)
        if node.history_origin
          hash['origin'] = { '_type' => 'DV_DATE_TIME', 'value' => node.history_origin.iso8601 }
        end
        hash['time'] = { '_type' => 'DV_DATE_TIME', 'value' => node.event_time.iso8601 } if node.event_time
        hash['width'] = { '_type' => 'DV_DURATION', 'value' => node.width } if node.width
        if node.math_function_code
          hash['math_function'] = {
            '_type' => 'DV_CODED_TEXT',
            'value' => node.math_function_code,
            'defining_code' => {
              '_type' => 'CODE_PHRASE',
              'terminology_id' => { 'value' => 'openehr' },
              'code_string' => node.math_function_code
            }
          }
        end
        return unless node.null_flavor_code

        hash['null_flavour'] = {
          '_type' => 'DV_CODED_TEXT',
          'value' => node.null_flavor_code,
          'defining_code' => {
            '_type' => 'CODE_PHRASE',
            'terminology_id' => { 'value' => 'openehr' },
            'code_string' => node.null_flavor_code
          }
        }
      end

      def merge_children(hash, node)
        node.children.group_by(&:rm_attribute_name).each do |attribute, children|
          serialized = children.sort_by(&:position).map { |child| serialize_node(child) }
          hash[attribute] = MULTIPLE_ATTRIBUTES.include?(attribute) ? serialized : serialized.first
        end
      end

      def merge_data_values(hash, node)
        node.data_values.each do |data_value|
          hash[data_value.rm_attribute_name] = data_value.to_canonical_hash
        end
      end
    end
  end
end

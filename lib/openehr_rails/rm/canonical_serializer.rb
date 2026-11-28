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
        context = serialize_context
        hash['context'] = context if context
        hash
      end

      # The setting written for a stored context that has none.
      def self.default_setting_hash
        code, value = OpenehrRails.default_setting
        setting_hash(code, value)
      end

      def self.setting_hash(code, value)
        {
          '_type' => 'DV_CODED_TEXT',
          'value' => value,
          'defining_code' => {
            '_type' => 'CODE_PHRASE',
            'terminology_id' => { 'value' => 'openehr' },
            'code_string' => code
          }
        }
      end

      private

      # EVENT_CONTEXT (#121, R-20261128-6 answer 4): written when a context
      # was committed, as committed; for a record whose context came only from
      # the committer's keyword (Storable's composed_at), only when the
      # composition's category is event -- a persistent composition gets no
      # context it was not given.
      def serialize_context
        return nil unless @composition.context_start_time
        return nil unless RecordedTimes.context_committed?(@composition) || event_category?

        {
          '_type' => 'EVENT_CONTEXT',
          'start_time' => { '_type' => 'DV_DATE_TIME',
                            'value' => RecordedTimes.value(@composition, :start_time,
                                                           @composition.context_start_time) },
          'setting' => setting
        }
      end

      def setting
        return self.class.default_setting_hash unless @composition.setting_code

        self.class.setting_hash(@composition.setting_code, @composition.setting_value)
      end

      def event_category?
        OpenehrRails.default_category.first.to_s == '433'
      end

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
          hash['origin'] = { '_type' => 'DV_DATE_TIME',
                             'value' => RecordedTimes.value(node, :origin, node.history_origin) }
        end
        if node.event_time
          hash['time'] = { '_type' => 'DV_DATE_TIME', 'value' => RecordedTimes.value(node, :time, node.event_time) }
        end
        hash['width'] = { '_type' => 'DV_DURATION', 'value' => node.width } if node.width
        action_archetype_id = node.extra.is_a?(Hash) ? node.extra['action_archetype_id'] : nil
        hash['action_archetype_id'] = action_archetype_id if action_archetype_id
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

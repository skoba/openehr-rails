# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Builds the persisted RM node graph from a canonical composition hash
    # (the shape Storable#to_rm_composition emits, also accepted from
    # external canonical JSON). Inverse of CanonicalSerializer.
    class GraphBuilder
      # Metadata keys that are not structural child attributes.
      RESERVED_KEYS = %w[_type archetype_node_id archetype_details name uid
                         feeder_audit links].freeze
      MULTIPLE_ATTRIBUTES = OpenehrRails::Storable::MULTIPLE_ATTRIBUTES

      # Node attributes stored as typed columns instead of child rows.
      SPECIAL_ATTRIBUTES = {
        'HISTORY' => %w[origin],
        'POINT_EVENT' => %w[time],
        'INTERVAL_EVENT' => %w[time width math_function],
        'ELEMENT' => %w[null_flavour]
      }.freeze

      def initialize(canonical_hash)
        @hash = canonical_hash
      end

      def composition_attributes
        details = @hash['archetype_details'] || {}
        {
          archetype_node_id: @hash['archetype_node_id'],
          template_id: details.dig('template_id', 'value'),
          name_value: @hash.dig('name', 'value'),
          uid: @hash.dig('uid', 'value'),
          rm_version: details['rm_version'] || '1.0.4'
        }.compact
      end

      def build!(composition)
        Array(@hash['content']).each_with_index do |entry_hash, index|
          build_node(composition, nil, 'content', entry_hash, index,
                     "/content[#{entry_hash['archetype_node_id']}]")
        end
        composition
      end

      private

      def build_node(composition, parent, attribute, hash, position, path)
        rm_type = hash['_type'] || infer_type(attribute, parent, hash)
        node = TypeMap.node_class_for(rm_type).create!(
          composition: composition,
          parent: parent,
          rm_attribute_name: attribute,
          position: position,
          path: path,
          archetype_node_id: hash['archetype_node_id'],
          archetype_id: hash.dig('archetype_details', 'archetype_id', 'value'),
          name_value: hash.dig('name', 'value'),
          **special_columns(rm_type, hash)
        )
        build_children(composition, node, rm_type, hash, path)
        node
      end

      def build_children(composition, node, rm_type, hash, path)
        hash.each do |key, value|
          next if RESERVED_KEYS.include?(key)
          next if SPECIAL_ATTRIBUTES.fetch(rm_type, []).include?(key)

          case value
          when Array
            value.each_with_index do |child, index|
              build_child(composition, node, key, child, index,
                          child_path(path, key, child))
            end
          when Hash
            build_child(composition, node, key, value, 0, child_path(path, key, value))
          end
        end
      end

      def build_child(composition, parent, attribute, hash, position, path)
        if data_value?(hash)
          build_data_value(composition, parent, attribute, hash, path)
        else
          build_node(composition, parent, attribute, hash, position, path)
        end
      end

      def build_data_value(composition, node, attribute, hash, path)
        rm_type = hash['_type']
        TypeMap.data_value_class_for(rm_type).create!(
          composition: composition,
          node: node,
          rm_attribute_name: attribute,
          path: path,
          **data_value_columns(rm_type, hash)
        )
      end

      def data_value?(hash)
        hash.is_a?(Hash) && TypeMap::DATA_VALUE_TYPES.key?(hash['_type'])
      end

      def child_path(path, attribute, hash)
        node_id = hash.is_a?(Hash) ? hash['archetype_node_id'] : nil
        suffix = node_id ? "[#{node_id}]" : ''
        "#{path}/#{attribute}#{suffix}"
      end

      # Mirrors Storable#new_rm_node for hashes lacking _type.
      def infer_type(attribute, parent, hash)
        case attribute
        when 'data'
          parent.is_a?(Observation) ? 'HISTORY' : 'ITEM_TREE'
        when 'events' then 'POINT_EVENT'
        when 'state', 'protocol', 'description' then 'ITEM_TREE'
        when 'activities' then 'ACTIVITY'
        when 'items' then hash.key?('value') ? 'ELEMENT' : 'CLUSTER'
        else
          hash.key?('value') ? 'ELEMENT' : 'CLUSTER'
        end
      end

      def special_columns(rm_type, hash)
        case rm_type
        when 'HISTORY'
          { history_origin: parse_time(hash.dig('origin', 'value')) }.compact
        when 'POINT_EVENT'
          { event_time: parse_time(hash.dig('time', 'value')) }.compact
        when 'INTERVAL_EVENT'
          {
            event_time: parse_time(hash.dig('time', 'value')),
            width: hash.dig('width', 'value'),
            math_function_code: hash.dig('math_function', 'defining_code', 'code_string')
          }.compact
        when 'ELEMENT'
          { null_flavor_code: hash.dig('null_flavour', 'defining_code', 'code_string') }.compact
        else
          {}
        end
      end

      def data_value_columns(rm_type, hash)
        case rm_type
        when 'DV_QUANTITY'
          { magnitude: hash['magnitude'], units: hash['units'], precision: hash['precision'] }.compact
        when 'DV_COUNT'
          { integer_value: hash['magnitude'] }
        when 'DV_TEXT'
          { text_value: hash['value'] }
        when 'DV_CODED_TEXT'
          { text_value: hash['value'],
            code_string: hash.dig('defining_code', 'code_string'),
            terminology_id: hash.dig('defining_code', 'terminology_id', 'value') }
        when 'DV_BOOLEAN'
          { boolean_value: hash['value'] }
        when 'DV_DATE'
          { date_value: hash['value'] }
        when 'DV_TIME'
          { time_value: hash['value'] }
        when 'DV_DATE_TIME'
          { datetime_value: parse_time(hash['value']) }
        when 'DV_DURATION'
          { duration_value: hash['value'] }
        when 'DV_PROPORTION'
          { numerator: hash['numerator'], denominator: hash['denominator'],
            proportion_type: hash['type'] }
        when 'DV_ORDINAL'
          { integer_value: hash['value'],
            text_value: hash.dig('symbol', 'value'),
            code_string: hash.dig('symbol', 'defining_code', 'code_string'),
            terminology_id: hash.dig('symbol', 'defining_code', 'terminology_id', 'value') }
        when 'DV_IDENTIFIER'
          { identifier_id: hash['id'], identifier_issuer: hash['issuer'],
            identifier_assigner: hash['assigner'], identifier_type: hash['type'] }.compact
        when 'DV_URI'
          { uri_value: hash['value'] }
        when 'DV_MULTIMEDIA'
          { media_type: hash['media_type'], uri_value: hash['uri'] }.compact
        when 'DV_PARSABLE'
          { text_value: hash['value'], formalism: hash['formalism'] }
        else
          { text_value: hash['value'].to_s }
        end
      end

      def parse_time(value)
        return value if value.nil? || value.respond_to?(:iso8601)

        Time.zone ? Time.zone.parse(value.to_s) : Time.parse(value.to_s)
      end
    end
  end
end

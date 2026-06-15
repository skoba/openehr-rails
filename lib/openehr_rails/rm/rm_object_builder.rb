# frozen_string_literal: true

require 'openehr'

module OpenehrRails
  module Rm
    # Builds a full OpenEHR::RM::Composition object from the stored
    # graph, injecting config defaults for mandatory attributes not
    # carried in OPT/stored data. The gem's own constructor validations
    # (ArgumentError on missing mandatory attrs) become the RM-conformance
    # check.
    class RmObjectBuilder
      # Map rm_type to the corresponding OpenEHR::RM class.
      TYPE_CLASSES = {
        'OBSERVATION' => OpenEHR::RM::Composition::Content::Entry::Observation,
        'EVALUATION' => OpenEHR::RM::Composition::Content::Entry::Evaluation,
        'ADMIN_ENTRY' => OpenEHR::RM::Composition::Content::Entry::AdminEntry,
        'HISTORY' => OpenEHR::RM::DataStructures::History::History,
        'POINT_EVENT' => OpenEHR::RM::DataStructures::History::PointEvent,
        'INTERVAL_EVENT' => OpenEHR::RM::DataStructures::History::IntervalEvent,
        'ITEM_TREE' => OpenEHR::RM::DataStructures::ItemStructure::ItemTree,
        'ITEM_LIST' => OpenEHR::RM::DataStructures::ItemStructure::ItemList,
        'CLUSTER' => OpenEHR::RM::DataStructures::ItemStructure::Representation::Cluster,
        'ELEMENT' => OpenEHR::RM::DataStructures::ItemStructure::Representation::Element
      }.freeze

      def initialize(composition)
        @composition = composition
      end

      def call
        build_composition
      end

      private

      def build_composition
        OpenEHR::RM::Composition::Composition.new(
          archetype_node_id: @composition.archetype_node_id,
          name: dv_text(@composition.name_value || @composition.archetype_node_id),
          language: code_phrase(
            @composition.language_code || OpenehrRails.default_language,
            'ISO_639-1'
          ),
          territory: code_phrase(
            @composition.territory_code || OpenehrRails.default_territory,
            'ISO_3166-1'
          ),
          category: dv_coded_text(
            *OpenehrRails.default_category,
            'openehr'
          ),
          composer: party_identified(@composition.composer_name || OpenehrRails.default_composer_name),
          content: @composition.content_nodes.map { |node| build_node(node) },
          context: build_event_context
        )
      end

      def build_event_context
        return nil unless @composition.context_start_time

        OpenEHR::RM::Composition::EventContext.new(
          start_time: dv_date_time(@composition.context_start_time),
          setting: code_phrase('other', 'openehr')
        )
      end

      def build_node(node)
        klass = TYPE_CLASSES[node.rm_type]
        attrs = {
          archetype_node_id: node.archetype_node_id,
          name: dv_text(node.name_value || node.archetype_node_id)
        }

        # Entry-specific mandatory attributes
        if [OpenehrRails::Rm::Observation, OpenehrRails::Rm::Evaluation,
            OpenehrRails::Rm::AdminEntry].any? { |c| node.is_a?(c) }
          attrs.merge!(
            language: code_phrase(OpenehrRails.default_language, 'ISO_639-1'),
            encoding: code_phrase(OpenehrRails.default_encoding, 'IANA_character-sets'),
            subject: party_self
          )
        end

        # Entry-specific: add data from first child
        if node.is_a?(OpenehrRails::Rm::EntryNode)
          data_child = node.children.find { |c| c.rm_attribute_name == 'data' }
          attrs[:data] = build_node(data_child) if data_child
        end

        # History-specific: origin is mandatory
        if node.is_a?(OpenehrRails::Rm::History)
          attrs[:origin] = dv_date_time(
            node.history_origin || node.composition.context_start_time || Time.current
          )
          attrs[:events] = node.children.sort_by(&:position).map { |c| build_node(c) }
        end

        # Event-specific: time is mandatory
        if [OpenehrRails::Rm::PointEvent, OpenehrRails::Rm::IntervalEvent]
           .any? { |c| node.is_a?(c) }
          attrs[:time] = dv_date_time(node.event_time || Time.current)
          attrs[:data] = build_node(
            node.children.find { |c| c.rm_attribute_name == 'data' }
          )
          if node.is_a?(OpenehrRails::Rm::IntervalEvent)
            attrs[:width] = parse_duration(node.width || 'PT0S')
            attrs[:math_function] = code_phrase(node.math_function_code || '144', 'openehr')
          end
        end

        # ItemStructure: items child list
        if [OpenehrRails::Rm::ItemTree, OpenehrRails::Rm::ItemList]
           .any? { |c| node.is_a?(c) }
          attrs[:items] = node.children.sort_by(&:position).map { |c| build_node(c) }
        end

        # Cluster: items child list
        if node.is_a?(OpenehrRails::Rm::Cluster)
          attrs[:items] = node.children.sort_by(&:position).map { |c| build_node(c) }
        end

        # Element: value leaf
        if node.is_a?(OpenehrRails::Rm::Element)
          dv = node.data_values.first
          attrs[:value] = build_data_value(dv) if dv
        end

        klass.new(attrs)
      end

      def build_data_value(dv)
        case dv.rm_type
        when 'DV_TEXT'
          dv_text(dv.text_value)
        when 'DV_CODED_TEXT'
          dv_coded_text(dv.text_value, dv.code_string, dv.terminology_id || 'local')
        when 'DV_QUANTITY'
          OpenEHR::RM::DataTypes::Quantity::DvQuantity.new(
            magnitude: dv.magnitude,
            units: dv.units,
            precision: dv.precision
          )
        when 'DV_COUNT'
          OpenEHR::RM::DataTypes::Quantity::DvCount.new(magnitude: dv.integer_value)
        when 'DV_BOOLEAN'
          OpenEHR::RM::DataTypes::Basic::DvBoolean.new(value: dv.boolean_value)
        when 'DV_DATE'
          OpenEHR::RM::DataTypes::Quantity::DateTime::DvDate.new(value: dv.date_value.iso8601)
        when 'DV_TIME'
          OpenEHR::RM::DataTypes::Quantity::DateTime::DvTime.new(value: dv.time_value.strftime('%H:%M:%S'))
        when 'DV_DATE_TIME'
          dv_date_time(dv.datetime_value)
        when 'DV_DURATION'
          OpenEHR::RM::DataTypes::Quantity::DateTime::DvDuration.new(value: dv.duration_value)
        when 'DV_IDENTIFIER'
          OpenEHR::RM::DataTypes::Basic::DvIdentifier.new(
            id: dv.identifier_id,
            issuer: dv.identifier_issuer,
            assigner: dv.identifier_assigner,
            type: dv.identifier_type
          )
        when 'DV_URI'
          OpenEHR::RM::DataTypes::URI::DvUri.new(value: dv.uri_value)
        when 'DV_PROPORTION'
          OpenEHR::RM::DataTypes::Quantity::DvProportion.new(
            numerator: dv.numerator,
            denominator: dv.denominator,
            type: dv.proportion_type || 1
          )
        else
          dv_text(dv.value.to_s)
        end
      end

      def dv_text(value)
        OpenEHR::RM::DataTypes::Text::DvText.new(value: value.to_s)
      end

      def dv_coded_text(value, code, terminology)
        OpenEHR::RM::DataTypes::Text::DvCodedText.new(
          value: value,
          defining_code: code_phrase(code, terminology)
        )
      end

      def code_phrase(code, terminology)
        OpenEHR::RM::DataTypes::Text::CodePhrase.new(
          terminology_id: terminology_id(terminology),
          code_string: code
        )
      end

      def terminology_id(name)
        OpenEHR::RM::Support::Identification::TerminologyID.new(name: name)
      end

      def dv_date_time(value)
        iso = value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
        OpenEHR::RM::DataTypes::Quantity::DateTime::DvDateTime.new(value: iso)
      end

      def parse_duration(iso_string)
        OpenEHR::RM::DataTypes::Quantity::DateTime::DvDuration.new(value: iso_string)
      end

      def party_self
        OpenEHR::RM::Common::Generic::PartySelf.new(external_ref: nil)
      end

      def party_identified(name)
        OpenEHR::RM::Common::Generic::PartyIdentified.new(name: name)
      end
    end
  end
end

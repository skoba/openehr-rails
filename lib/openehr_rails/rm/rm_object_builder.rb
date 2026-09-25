# frozen_string_literal: true

require 'openehr'

module OpenehrRails
  module Rm
    # Raised by RmObjectBuilder for a stored node whose rm_type the graph
    # accepts (Rm::TypeMap::NODE_TYPES) but the read side cannot rebuild
    # (RmObjectBuilder::TYPE_CLASSES) -- SECTION, INSTRUCTION, ACTIVITY,
    # ACTION, ITEM_SINGLE, ITEM_TABLE today (#44; #45 narrows the gap).
    # Names the composition and the node so a warning built from it is
    # actionable.
    class UnsupportedRmTypeError < StandardError
      attr_reader :composition_uid, :rm_type, :path

      def initialize(composition, node)
        @composition_uid = composition.uid
        @rm_type = node.rm_type
        @path = node.path
        super(
          "composition uid=#{composition.uid}: node #{node.path} has rm_type #{node.rm_type}, " \
          'which RmObjectBuilder::TYPE_CLASSES cannot rebuild as an OpenEHR::RM object'
        )
      end
    end

    # Builds a full OpenEHR::RM::Composition object from the stored
    # graph, injecting config defaults for mandatory attributes not
    # carried in OPT/stored data. The gem's own constructor validations
    # (ArgumentError on missing mandatory attrs) become the RM-conformance
    # check.
    #
    # Injected values, all documented approximations (#45 ruling condition
    # (a); the graph does not carry them yet, phase B adds columns):
    #   - ENTRY language / encoding / subject: OpenehrRails config defaults
    #   - HISTORY.origin, EVENT.time: composition context time or now
    #   - INSTRUCTION.narrative: the node's name when no narrative row exists
    #   - ACTIVITY.action_archetype_id: '/.*/' (any ACTION archetype)
    # rubocop:disable-next Metrics/ClassLength
    class RmObjectBuilder
      # The RM's "any ACTION archetype" pattern, injected because the graph
      # cannot carry ACTIVITY.action_archetype_id yet (see class comment).
      DEFAULT_ACTION_ARCHETYPE_ID = '/.*/'

      # Map rm_type to the corresponding OpenEHR::RM class. ACTION,
      # ITEM_SINGLE and ITEM_TABLE are persisted by GraphBuilder but not
      # rebuilt here yet (UnsupportedRmTypeError; #44 skips them in AQL).
      TYPE_CLASSES = {
        'SECTION' => OpenEHR::RM::Composition::Content::Navigation::Section,
        'OBSERVATION' => OpenEHR::RM::Composition::Content::Entry::Observation,
        'EVALUATION' => OpenEHR::RM::Composition::Content::Entry::Evaluation,
        'INSTRUCTION' => OpenEHR::RM::Composition::Content::Entry::Instruction,
        'ACTIVITY' => OpenEHR::RM::Composition::Content::Entry::Activity,
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
          uid: OpenEHR::RM::Support::Identification::HierObjectID.new(value: @composition.uid),
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
          setting: dv_coded_text('other', 'other', 'openehr')
        )
      end

      def node_class(node)
        TYPE_CLASSES.fetch(node.rm_type) { raise UnsupportedRmTypeError.new(@composition, node) }
      end

      # One helper per stored node type; each adds the attributes the
      # corresponding RM constructor needs, injecting the documented defaults
      # where the graph carries nothing.
      def build_node(node)
        klass = node_class(node)
        attrs = {
          archetype_node_id: node.archetype_node_id,
          name: dv_text(node.name_value || node.archetype_node_id)
        }
        attrs.merge!(entry_attributes(node)) if node.is_a?(OpenehrRails::Rm::EntryNode)
        attrs.merge!(section_attributes(node)) if node.is_a?(OpenehrRails::Rm::Section)
        attrs.merge!(instruction_attributes(node)) if node.is_a?(OpenehrRails::Rm::Instruction)
        attrs.merge!(activity_attributes(node)) if node.is_a?(OpenehrRails::Rm::Activity)
        attrs.merge!(history_attributes(node)) if node.is_a?(OpenehrRails::Rm::History)
        attrs.merge!(event_attributes(node)) if event?(node)
        attrs[:items] = child_nodes(node) if item_container?(node)
        attrs.merge!(element_attributes(node)) if node.is_a?(OpenehrRails::Rm::Element)
        klass.new(attrs)
      end

      # ENTRY: language / encoding / subject are mandatory on every RM ENTRY
      # and not stored, so the config defaults are injected; `data` for the
      # entries that have one; `protocol` for every CARE_ENTRY that stored one
      # (#45 -- INSTRUCTION keeps its requester/receiver there).
      def entry_attributes(node)
        attrs = {
          language: code_phrase(OpenehrRails.default_language, 'ISO_639-1'),
          encoding: code_phrase(OpenehrRails.default_encoding, 'IANA_character-sets'),
          subject: party_self
        }
        data = child_node(node, 'data')
        attrs[:data] = build_node(data) if data
        protocol = child_node(node, 'protocol')
        attrs[:protocol] = build_node(protocol) if protocol
        attrs
      end

      # SECTION.items must be nil or non-empty for the RM constructor.
      def section_attributes(node)
        items = child_nodes(node)
        items.empty? ? {} : { items: items }
      end

      # INSTRUCTION.narrative is mandatory; the graph stores it as a
      # `narrative` data-value row. When that row is absent the node's name
      # stands in -- an approximation (#45 ruling condition (a)); phase B
      # persists narrative as a column.
      def instruction_attributes(node)
        narrative = data_value_row(node, 'narrative')
        attrs = { narrative: narrative ? dv_text(narrative.text_value) : dv_text(node.name_value || node.archetype_node_id) }
        activities = child_nodes(node, 'activities')
        attrs[:activities] = activities unless activities.empty?
        expiry = data_value_row(node, 'expiry_time')
        attrs[:expiry_time] = dv_date_time(expiry.datetime_value) if expiry&.datetime_value
        attrs
      end

      # ACTIVITY.description is mandatory and never defaulted: a graph without
      # one fails RM conformance (the gem raises, #44 reports and skips).
      # action_archetype_id is mandatory too but the graph cannot carry it
      # (GraphBuilder drops String-valued attributes), so the RM's "any ACTION
      # archetype" pattern is injected -- an approximation (#45 ruling
      # condition (a)); phase B persists the real value.
      def activity_attributes(node)
        attrs = { action_archetype_id: DEFAULT_ACTION_ARCHETYPE_ID }
        description = child_node(node, 'description')
        attrs[:description] = build_node(description) if description
        timing = data_value_row(node, 'timing')
        attrs[:timing] = dv_parsable(timing.text_value, timing.formalism) if timing
        attrs
      end

      # HISTORY.origin is mandatory.
      def history_attributes(node)
        {
          origin: dv_date_time(node.history_origin || node.composition.context_start_time || Time.current),
          events: child_nodes(node)
        }
      end

      def event?(node)
        node.is_a?(OpenehrRails::Rm::PointEvent) || node.is_a?(OpenehrRails::Rm::IntervalEvent)
      end

      # EVENT.time and .data are mandatory; INTERVAL_EVENT adds width and
      # math_function.
      def event_attributes(node)
        attrs = { time: dv_date_time(node.event_time || Time.current), data: build_node(child_node(node, 'data')) }
        if node.is_a?(OpenehrRails::Rm::IntervalEvent)
          attrs[:width] = parse_duration(node.width || 'PT0S')
          attrs[:math_function] = code_phrase(node.math_function_code || '144', 'openehr')
        end
        attrs
      end

      def item_container?(node)
        node.is_a?(OpenehrRails::Rm::ItemTree) || node.is_a?(OpenehrRails::Rm::ItemList) ||
          node.is_a?(OpenehrRails::Rm::Cluster)
      end

      def element_attributes(node)
        dv = node.data_values.first
        dv ? { value: build_data_value(dv) } : {}
      end

      def child_node(node, attribute)
        node.children.find { |c| c.rm_attribute_name == attribute }
      end

      # Children in position order, optionally restricted to one RM attribute
      # (INSTRUCTION has `activities` and `protocol` children side by side).
      def child_nodes(node, attribute = nil)
        children = node.children.sort_by(&:position)
        children = children.select { |c| c.rm_attribute_name == attribute } if attribute
        children.map { |c| build_node(c) }
      end

      def data_value_row(node, attribute)
        node.data_values.find { |dv| dv.rm_attribute_name == attribute }
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

      def dv_parsable(value, formalism)
        OpenEHR::RM::DataTypes::Encapsulated::DvParsable.new(value: value.to_s, formalism: formalism)
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

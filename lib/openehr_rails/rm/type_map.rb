# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Bidirectional map between openEHR RM type names (the STI values
    # stored in the rm_type column, identical to canonical JSON `_type`)
    # and the OpenehrRails::Rm model classes.
    module TypeMap
      NODE_TYPES = {
        'SECTION' => 'Section',
        'OBSERVATION' => 'Observation',
        'EVALUATION' => 'Evaluation',
        'INSTRUCTION' => 'Instruction',
        'ACTION' => 'Action',
        'ADMIN_ENTRY' => 'AdminEntry',
        'ACTIVITY' => 'Activity',
        'HISTORY' => 'History',
        'POINT_EVENT' => 'PointEvent',
        'INTERVAL_EVENT' => 'IntervalEvent',
        'ITEM_TREE' => 'ItemTree',
        'ITEM_LIST' => 'ItemList',
        'ITEM_SINGLE' => 'ItemSingle',
        'ITEM_TABLE' => 'ItemTable',
        'CLUSTER' => 'Cluster',
        'ELEMENT' => 'Element'
      }.freeze

      DATA_VALUE_TYPES = {
        'DV_TEXT' => 'DvText',
        'DV_CODED_TEXT' => 'DvCodedText',
        'DV_QUANTITY' => 'DvQuantity',
        'DV_COUNT' => 'DvCount',
        'DV_PROPORTION' => 'DvProportion',
        'DV_ORDINAL' => 'DvOrdinal',
        'DV_BOOLEAN' => 'DvBoolean',
        'DV_DATE' => 'DvDate',
        'DV_TIME' => 'DvTime',
        'DV_DATE_TIME' => 'DvDateTime',
        'DV_DURATION' => 'DvDuration',
        'DV_IDENTIFIER' => 'DvIdentifier',
        'DV_URI' => 'DvUri',
        'DV_MULTIMEDIA' => 'DvMultimedia',
        'DV_PARSABLE' => 'DvParsable'
      }.freeze

      CLASS_TO_TYPE = NODE_TYPES.merge(DATA_VALUE_TYPES).invert.freeze

      module_function

      def rm_type_for(klass)
        CLASS_TO_TYPE[klass.name.split('::').last]
      end

      def node_class_for(rm_type)
        const = NODE_TYPES[rm_type]
        raise ArgumentError, "unknown RM node type #{rm_type.inspect}" unless const

        OpenehrRails::Rm.const_get(const)
      end

      def data_value_class_for(rm_type)
        const = DATA_VALUE_TYPES[rm_type]
        raise ArgumentError, "unknown RM data value type #{rm_type.inspect}" unless const

        OpenehrRails::Rm.const_get(const)
      end
    end
  end
end

# frozen_string_literal: true

module OpenehrRails
  module Rm
    # STI base for all LOCATABLE structure nodes of a stored composition
    # (entries, histories, events, item structures, clusters, elements).
    # The inheritance column `rm_type` stores openEHR type names
    # ("OBSERVATION", "ITEM_TREE", ...) matching canonical JSON `_type`.
    class Node < ActiveRecord::Base
      self.table_name = 'openehr_rm_nodes'
      self.inheritance_column = 'rm_type'

      belongs_to :composition, class_name: 'OpenehrRails::Rm::Composition',
                               inverse_of: :nodes
      belongs_to :parent, class_name: 'OpenehrRails::Rm::Node', optional: true,
                          inverse_of: :children
      has_many :children, -> { order(:position) },
               class_name: 'OpenehrRails::Rm::Node', foreign_key: :parent_id,
               inverse_of: :parent, dependent: nil
      has_many :data_values, class_name: 'OpenehrRails::Rm::DataValue',
                             foreign_key: :node_id, inverse_of: :node,
                             dependent: nil
      has_one :value_dv, -> { where(rm_attribute_name: 'value') },
              class_name: 'OpenehrRails::Rm::DataValue', foreign_key: :node_id

      validates :rm_attribute_name, presence: true
      validates :path, presence: true

      class << self
        def sti_name
          TypeMap.rm_type_for(self) || super
        end

        def find_sti_class(type_name)
          TypeMap.node_class_for(type_name)
        end

        def sti_class_for(type_name)
          TypeMap.node_class_for(type_name)
        end
      end
    end
  end
end

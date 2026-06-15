# frozen_string_literal: true

module OpenehrRails
  module Rm
    # STI base for stored DATA_VALUE leaves (DV_*). Each subclass maps its
    # openEHR attributes onto the shared typed columns and implements
    # #value (polymorphic reader) and #to_canonical_hash (must emit the
    # exact shape Storable#rm_value writes into the JSON cache).
    class DataValue < ActiveRecord::Base
      self.table_name = 'openehr_rm_data_values'
      self.inheritance_column = 'rm_type'

      belongs_to :node, class_name: 'OpenehrRails::Rm::Node',
                        inverse_of: :data_values
      belongs_to :composition, class_name: 'OpenehrRails::Rm::Composition',
                               inverse_of: :data_values

      validates :rm_attribute_name, presence: true
      validates :path, presence: true

      scope :at_path, ->(path) { where(path: path) }
      scope :latest, -> { joins(:composition).merge(Composition.latest) }

      class << self
        def sti_name
          TypeMap.rm_type_for(self) || super
        end

        def find_sti_class(type_name)
          TypeMap.data_value_class_for(type_name)
        end

        def sti_class_for(type_name)
          TypeMap.data_value_class_for(type_name)
        end

        # Type-aware value matching across the typed columns; used by the
        # AQL path fallback where the caller does not know the DV type.
        def matching(value)
          case value
          when Numeric
            where(magnitude: value.to_f)
              .or(where(integer_value: value.to_i))
              .or(where(numerator: value.to_f))
          when true, false
            where(boolean_value: value)
          when Date, Time, DateTime
            where(datetime_value: value)
              .or(where(date_value: value))
          else
            text = value.to_s
            where(text_value: text)
              .or(where(code_string: text))
              .or(where(uri_value: text))
              .or(where(duration_value: text))
              .or(where(identifier_id: text))
          end
        end
      end

      def value
        raise NotImplementedError, "#{self.class.name} must implement #value"
      end

      def to_canonical_hash
        raise NotImplementedError, "#{self.class.name} must implement #to_canonical_hash"
      end
    end
  end
end

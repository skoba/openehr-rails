# frozen_string_literal: true

module OpenehrRails
  module Rm
    class DvText < DataValue
      validates :text_value, presence: true

      def value = text_value

      def to_canonical_hash
        { '_type' => 'DV_TEXT', 'value' => text_value }
      end
    end

    class DvCodedText < DvText
      validates :code_string, presence: true

      def to_canonical_hash
        {
          '_type' => 'DV_CODED_TEXT',
          'value' => text_value,
          'defining_code' => {
            '_type' => 'CODE_PHRASE',
            'terminology_id' => { 'value' => terminology_id || 'local' },
            'code_string' => code_string
          }
        }
      end
    end

    class DvQuantity < DataValue
      validates :magnitude, presence: true
      validates :units, presence: true

      def value = magnitude

      def to_canonical_hash
        { '_type' => 'DV_QUANTITY', 'magnitude' => magnitude, 'units' => units }
      end
    end

    class DvCount < DataValue
      validates :integer_value, presence: true

      def value = integer_value

      def to_canonical_hash
        { '_type' => 'DV_COUNT', 'magnitude' => integer_value }
      end
    end

    class DvProportion < DataValue
      validates :numerator, presence: true
      validates :denominator, presence: true

      def value
        denominator.zero? ? nil : numerator / denominator
      end

      def to_canonical_hash
        { '_type' => 'DV_PROPORTION', 'numerator' => numerator,
          'denominator' => denominator, 'type' => proportion_type || 1 }
      end
    end

    class DvOrdinal < DataValue
      validates :integer_value, presence: true
      validates :code_string, presence: true

      def value = integer_value

      def to_canonical_hash
        {
          '_type' => 'DV_ORDINAL',
          'value' => integer_value,
          'symbol' => {
            '_type' => 'DV_CODED_TEXT',
            'value' => text_value,
            'defining_code' => {
              '_type' => 'CODE_PHRASE',
              'terminology_id' => { 'value' => terminology_id || 'local' },
              'code_string' => code_string
            }
          }
        }
      end
    end

    class DvBoolean < DataValue
      validates :boolean_value, inclusion: { in: [true, false] }

      def value = boolean_value

      def to_canonical_hash
        { '_type' => 'DV_BOOLEAN', 'value' => boolean_value }
      end
    end

    class DvDate < DataValue
      validates :date_value, presence: true

      def value = date_value

      def to_canonical_hash
        { '_type' => 'DV_DATE', 'value' => date_value.iso8601 }
      end
    end

    class DvTime < DataValue
      validates :time_value, presence: true

      def value = time_value

      def to_canonical_hash
        { '_type' => 'DV_TIME', 'value' => time_value.strftime('%H:%M:%S') }
      end
    end

    class DvDateTime < DataValue
      validates :datetime_value, presence: true

      def value = datetime_value

      def to_canonical_hash
        { '_type' => 'DV_DATE_TIME', 'value' => datetime_value.iso8601 }
      end
    end

    class DvDuration < DataValue
      validates :duration_value, presence: true, format: { with: /\AP/ }

      def value = duration_value

      def to_canonical_hash
        { '_type' => 'DV_DURATION', 'value' => duration_value }
      end
    end

    class DvIdentifier < DataValue
      validates :identifier_id, presence: true

      def value = identifier_id

      def to_canonical_hash
        { '_type' => 'DV_IDENTIFIER', 'id' => identifier_id,
          'issuer' => identifier_issuer, 'assigner' => identifier_assigner,
          'type' => identifier_type }.compact
      end
    end

    class DvUri < DataValue
      validates :uri_value, presence: true

      def value = uri_value

      def to_canonical_hash
        { '_type' => 'DV_URI', 'value' => uri_value }
      end
    end

    class DvMultimedia < DataValue
      validates :media_type, presence: true

      def value = uri_value

      def to_canonical_hash
        { '_type' => 'DV_MULTIMEDIA', 'media_type' => media_type,
          'uri' => uri_value }.compact
      end
    end

    class DvParsable < DataValue
      validates :formalism, presence: true

      def value = text_value

      def to_canonical_hash
        { '_type' => 'DV_PARSABLE', 'value' => text_value, 'formalism' => formalism }
      end
    end
  end
end

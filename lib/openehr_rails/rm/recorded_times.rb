# frozen_string_literal: true

module OpenehrRails
  module Rm
    # The committed strings of EVENT_CONTEXT.start_time, HISTORY.origin and
    # EVENT.time (#121; plan docs/design/121-122-structural-date-times-plan.md
    # section 2, option A, R-20261128-6 answer 1). The instant columns
    # (context_start_time, history_origin, event_time) keep the normalized
    # value for ordering and AQL; the string, as written, is kept in the row's
    # `extra` JSON column, which both tables have had since the RM tables were
    # introduced (0.3.0). A database without the column keeps working as
    # before: nothing is written there, and reads fall back to the instant.
    module RecordedTimes
      KEYS = { start_time: 'start_time_value', origin: 'origin_value', time: 'time_value' }.freeze
      CONTEXT_KEY = 'context'

      module_function

      # Column attributes for a row of +model+: {extra: {...}} holding the
      # given strings (and whether a context was committed), or {} when the
      # table has no `extra` column or nothing is to be kept.
      def extra_columns(model, committed_context: false, **values)
        return {} unless extra_column?(model)

        extra = values.each_with_object({}) do |(name, value), kept|
          kept[KEYS.fetch(name)] = value if value.is_a?(String) && value.present?
        end
        extra[CONTEXT_KEY] = true if committed_context
        extra.empty? ? {} : { extra: extra }
      end

      def extra_column?(model)
        model.column_names.include?('extra')
      end

      # The recorded string for +name+ on +row+, or nil.
      def recorded(row, name)
        extra = row.has_attribute?(:extra) ? row.extra : nil
        extra.is_a?(Hash) ? extra[KEYS.fetch(name)].presence : nil
      end

      def context_committed?(composition)
        extra = composition.has_attribute?(:extra) ? composition.extra : nil
        extra.is_a?(Hash) && extra[CONTEXT_KEY] == true
      end

      # The value to write back: the recorded string, else the instant.
      def value(row, name, instant)
        recorded(row, name) || instant&.iso8601
      end
    end
  end
end

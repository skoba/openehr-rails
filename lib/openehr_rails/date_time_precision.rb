# frozen_string_literal: true

require 'active_support/concern'

module OpenehrRails
  # Validation included by Storable (#122). A scaffolded model keeps a
  # DV_DATE / DV_DATE_TIME / DV_TIME field in a date, datetime or time column,
  # and Active Record's cast drops or alters values openEHR allows: `2026-11`
  # becomes nil, `2026-11-05T09` midnight, `09` 09:00:00. Such a value is a
  # validation error naming it, not a silent change. A string column holds any
  # value and is left alone; full values pass.
  module DateTimePrecision
    extend ActiveSupport::Concern

    RM_TYPES = %w[DV_DATE DV_DATE_TIME DV_TIME].freeze
    OFFSET = '(Z|[+-]\d{2}(:?\d{2})?)?'

    # Forms the column alters; any form it cannot read at all casts to nil
    # and is refused too (plan docs/design/121-122-structural-date-times-plan.md
    # section 5, option A).
    ALTERED_FORMS = {
      # a time to the hour: the cast drops the hour (a year or a year-month
      # casts to nil). A date with no time is not listed in the plan (section 5)
      # and still saves as midnight.
      datetime: [/\A\d{4}-\d{2}-\d{2}T\d{2}#{OFFSET}\z/],
      # a time to the hour: the cast fills in the minutes
      time: [/\A\d{2}#{OFFSET}\z/],
      date: []
    }.freeze

    MESSAGE = 'cannot hold %<value>s at the precision it was given'

    included do
      validate :refuse_lossy_date_times
    end

    private

    def refuse_lossy_date_times
      self.class::FIELD_MAP.each do |name, field|
        next unless RM_TYPES.include?(field[:rm_type])

        raw = read_attribute_before_type_cast(name.to_s)
        next unless lossy_date_time?(name, raw)

        errors.add(name, :partial_date_time, value: raw, message: MESSAGE)
      end
    end

    def lossy_date_time?(name, raw)
      forms = ALTERED_FORMS[self.class.type_for_attribute(name.to_s).type]
      return false if forms.nil? || !raw.is_a?(String) || raw.strip.empty?

      public_send(name).nil? || forms.any? { |form| form.match?(raw.strip) }
    end
  end
end

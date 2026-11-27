# frozen_string_literal: true

require 'openehr'

module OpenehrRails
  module Rm
    # The normalized value a DV_DATE_TIME or DV_DATE is ordered and searched by
    # (#109, R-20261127-31): the earliest instant (day) the value covers, a
    # value without an offset read as UTC. This is the instant the openehr gem
    # orders the value by (ISO8601DateTimeModule#utc_seconds and
    # #calendar_days, openehr 2.9.0 #120, #112); the spec pins the two equal.
    #
    # The value is read with the gem's own ISO 8601 reader. The instant is
    # assembled here from the parts it reads, not from DvDateTime#magnitude:
    # the magnitude is a Float that drifts at microseconds, and before openehr
    # 2.9.0 it counted differently (#117, #120). The reader gives the same
    # parts from openehr 2.6.1 (the gemspec floor) on.
    #
    # The normalized value is internal. The committed string is kept and
    # returned unchanged (#63); nothing here is shown.
    module PartialTemporal
      OFFSET = /\A([+-])(\d{2}):?(\d{2})\z/

      module_function

      # The earliest UTC instant of an ISO 8601 date-time string, or nil when
      # the gem does not read it.
      def instant(string)
        parts = OpenEHR::AssumedLibraryTypes::ISO8601DateTime.new(string.to_s)
        Time.utc(parts.year, parts.month || 1, parts.day || 1, parts.hour || 0, parts.minute || 0,
                 seconds(parts)) - offset_seconds(parts.timezone)
      rescue ArgumentError
        nil
      end

      # The earliest day of an ISO 8601 date string, or nil when the gem does
      # not read it.
      def date(string)
        parts = OpenEHR::AssumedLibraryTypes::ISO8601Date.new(string.to_s)
        Date.new(parts.year, parts.month || 1, parts.day || 1)
      rescue ArgumentError
        nil
      end

      # Whole and fractional seconds, the fraction as an exact decimal.
      def seconds(parts)
        fraction = parts.fractional_second
        (parts.second || 0) + (fraction ? Rational(fraction.to_s) : 0)
      end

      # East of UTC positive; Z and no offset give 0.
      def offset_seconds(timezone)
        match = OFFSET.match(timezone.to_s)
        return 0 unless match

        seconds = (match[2].to_i * 3600) + (match[3].to_i * 60)
        match[1] == '-' ? -seconds : seconds
      end
    end
  end
end

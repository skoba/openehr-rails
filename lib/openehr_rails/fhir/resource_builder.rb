# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Builds the HL7 FHIR R5 resource for one archetype entry from plain
    # values, independent of where the record lives (#101): a scaffolded
    # Storable model (Serializer) or a composition in the RM graph
    # (RuntimeRecord).
    #
    # The resource is the one the entry's profile describes (#104):
    # - Observation entries: single-leaf entries use value[x], multi-leaf
    #   entries use component[];
    # - entries with a TypeMap::ENTRY_ELEMENT_MAPS row (problem_diagnosis ->
    #   Condition): each mapped leaf on its element, the archetype coding on
    #   the :anchor element; unmapped leaves are left out;
    # - any other entry: nothing (nil), as for its profile.
    #
    #   entry          - ResourceRegistry::Entry (archetype_id, fields)
    #   values         - {field name => value}; a field is "present" when its
    #                    value is truthy (as before #101)
    #   units          - {field name => unit} overriding the field's own :units
    #   displays       - {field name => display} for coded values, overriding
    #                    the OPT's code_labels (the record's own text)
    #   terminologies  - {field name => terminology} overriding the field's
    #   id             - the resource id
    #   subject_ehr_id - becomes subject Patient/<ehr_id> when present
    #   effective_at   - Time, or a recorded string (#121), for
    #                    effectiveDateTime (Observation), or nil
    class ResourceBuilder
      ARCHETYPE_SYSTEM = ResourceRegistry::ARCHETYPE_SYSTEM
      UCUM_SYSTEM = 'http://unitsofmeasure.org'
      # Condition.clinicalStatus (1..1, required binding to the R5 value set
      # condition-clinical): code system and display as THO 3.0.0 defines them.
      CONDITION_CLINICAL_SYSTEM = 'http://terminology.hl7.org/CodeSystem/condition-clinical'
      CONDITION_CLINICAL = {
        'unknown' => 'Unknown',
        'inactive' => 'Inactive'
      }.freeze
      # A FHIR dateTime as recorded: YYYY, YYYY-MM, YYYY-MM-DD, or a full
      # date-time with seconds and an offset.
      FHIR_DATE_TIME = /\A\d{4}(-\d{2}(-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2}))?)?)?\z/
      # A value to the hour (YYYY-MM-DDThh, with or without an offset): FHIR
      # has no form for it, and minutes are not made up (#110).
      TO_THE_HOUR = /\A(\d{4}-\d{2}-\d{2})T\d{2}(Z|[+-]\d{2}(:?\d{2})?)?\z/
      # A FHIR time (hh:mm:ss, optional fraction; no offset).
      FHIR_TIME = /\A\d{2}:\d{2}:\d{2}(\.\d+)?\z/
      TIME_OFFSET = /(Z|[+-]\d{2}(:?\d{2})?)\z/

      # rubocop:disable-next Metrics/ParameterLists -- keyword arguments, each optional but values/id
      def initialize(entry, values:, id:, units: {}, displays: {}, terminologies: {}, subject_ehr_id: nil,
                     effective_at: nil)
        @entry = entry
        @values = values
        @units = units
        @displays = displays
        @terminologies = terminologies
        @id = id
        @subject_ehr_id = subject_ehr_id
        @effective_at = effective_at
      end

      # nil when no field of the entry has a value, or the entry is not served.
      def build
        return build_observation if @entry.resource_type == 'Observation'

        element_map = TypeMap.element_map_for(@entry.archetype_id)
        element_map ? build_mapped(element_map) : nil
      end

      private

      def build_observation
        fields = @entry.fields.select { |field| @values[field[:name]] }
        return nil if fields.empty?

        observation = {
          resourceType: 'Observation',
          id: @id,
          status: 'final',
          code: { coding: [archetype_coding] }
        }
        observation[:subject] = subject if subject
        observation[:effectiveDateTime] = date_time_string(@effective_at) if @effective_at

        if fields.size == 1
          observation.merge!(value_entry(fields.first))
        else
          observation[:component] = fields.map { |field| component_entry(field) }
        end
        observation
      end

      # problem_diagnosis -> Condition (multi-leaf-non-observation-plan 8.1).
      def build_mapped(element_map)
        leaves = @entry.fields.filter_map do |field|
          leaf = element_map[:leaves][field[:node_id]]
          [leaf[:element], field] if leaf && @values[field[:name]]
        end
        return nil if leaves.empty?

        resource = { resourceType: @entry.resource_type, id: @id }
        resource[element_map[:anchor].to_sym] = [{ coding: [archetype_coding] }]
        resource[:subject] = subject if subject
        leaves.each { |element, field| resource[element.to_sym] = element_value(field) }
        resource[:clinicalStatus] = clinical_status(resource) if @entry.resource_type == 'Condition'
        resource
      end

      # Not in the record (the archetype has none); the facade sets it
      # (R-20261127-24): inactive when a date/time of resolution was recorded
      # -- it covers resolution or remission, and inactive holds both and
      # satisfies con-3 -- else unknown, as a null flavor.
      def clinical_status(resource)
        code = resource[:abatementDateTime] ? 'inactive' : 'unknown'
        { coding: [{ system: CONDITION_CLINICAL_SYSTEM, code: code, display: CONDITION_CLINICAL.fetch(code) }] }
      end

      def archetype_coding
        { system: ARCHETYPE_SYSTEM, code: @entry.archetype_id }
      end

      def subject
        { reference: "Patient/#{@subject_ehr_id}" } if @subject_ehr_id.present?
      end

      # A mapped leaf's value: coded and text leaves become CodeableConcept,
      # date/time leaves the recorded string.
      def element_value(field)
        case field[:rm_type]
        when 'DV_CODED_TEXT' then fhir_value(field)
        when 'DV_TEXT' then { text: @values[field[:name]].to_s }
        else date_time_string(@values[field[:name]])
        end
      end

      # A FHIR dateTime (R-20261127-24; Observation leaves too since #110). A
      # valid value stays as recorded. A value with a time but no offset is
      # read as UTC, as Observation.effectiveDateTime is (context start time);
      # missing seconds are filled in; a value to the hour is served to the
      # day; basic-format values become extended. Anything else is passed on
      # as recorded. A typed column's Time or Date (scaffold path) is ISO 8601.
      def date_time_string(value)
        return value.iso8601 if value.respond_to?(:iso8601)

        string = value.to_s
        return string if string.match?(FHIR_DATE_TIME)

        to_the_hour = TO_THE_HOUR.match(string)
        return to_the_hour[1] if to_the_hour

        parts = Date._iso8601(string)
        return string unless parts[:year] && parts[:mon] && parts[:mday]
        return format('%<year>04d-%<mon>02d-%<mday>02d', parts) unless parts[:hour]

        time_from(parts, string[/[.,](\d+)/, 1].to_s.length)
      end

      def time_from(parts, fraction_digits)
        seconds = (parts[:sec] || 0) + (parts[:sec_fraction] || 0)
        time = Time.new(parts[:year], parts[:mon], parts[:mday], parts[:hour], parts[:min] || 0, seconds,
                        parts[:offset] || 0)
        string = time.iso8601(fraction_digits.clamp(0, 9))
        parts[:offset] ? string : string.sub(/\+00:00\z/, 'Z')
      end

      # A FHIR time (#110): hh:mm:ss, seconds zero-filled. FHIR time SHALL NOT
      # carry an offset, so the clock reading as recorded is served and the
      # offset left out (converting to UTC would serve a reading the record
      # does not show). A value to the hour has no FHIR form and is left out
      # (nil). A typed column's Time (scaffold path) gives its clock reading.
      def time_string(value)
        if value.respond_to?(:strftime)
          return value.strftime('%H:%M:%S') if value.subsec.zero?

          return value.strftime('%H:%M:%S.%N').sub(/0+\z/, '')
        end

        string = value.to_s.sub(TIME_OFFSET, '')
        return string if string.match?(FHIR_TIME)
        return "#{string}:00" if string.match?(/\A\d{2}:\d{2}\z/)
        return nil if string.match?(/\A\d{2}\z/)

        value.to_s
      end

      def value_entry(field)
        { value_key(field) => fhir_value(field) }.compact
      end

      def component_entry(field)
        {
          code: { coding: [{ system: ARCHETYPE_SYSTEM, code: "#{field[:archetype_id]}##{field[:node_id]}" }] },
          value_key(field) => fhir_value(field)
        }.compact
      end

      def value_key(field)
        :"value#{TypeMap.datatype_for(field[:rm_type]).camelize}"
      end

      def fhir_value(field)
        value = @values[field[:name]]
        case field[:rm_type]
        when 'DV_QUANTITY'
          units = @units[field[:name]] || field[:units]
          { value: value, unit: units, system: UCUM_SYSTEM, code: units }
        when 'DV_CODED_TEXT'
          { coding: [{ system: @terminologies[field[:name]] || field[:terminology_id] || 'local', code: value,
                       display: @displays[field[:name]] || field[:code_labels]&.fetch(value, value) || value }] }
        when 'DV_COUNT'
          value.to_i
        when 'DV_BOOLEAN'
          value
        when 'DV_DATE_TIME', 'DV_DATE'
          date_time_string(value)
        when 'DV_TIME'
          time_string(value)
        else
          value.to_s
        end
      end
    end
  end
end

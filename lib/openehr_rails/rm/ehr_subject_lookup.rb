# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Finds the EHR for a subject (#95): openEHR ITS-REST EHR API "Get EHR by
    # subject id", GET /ehr?subject_id=&subject_namespace=. Both parameters
    # are matched against EHR_STATUS.subject.external_ref (id.value and
    # namespace). The specification defines 200 (the EHR) and 404 (none).
    #
    # Two outcomes are this implementation's own; the specification does not
    # cover them (R-20261127-6):
    # - several EHRs for one subject: :conflict with every matching ehr_id,
    #   oldest first. Nothing prevents a second EHR for a subject today, and
    #   picking one silently could hand back another patient's record.
    # - a missing or blank parameter: :bad_request.
    class EhrSubjectLookup
      Result = Struct.new(:status, :ehr, :ehr_ids, :error, keyword_init: true)

      def initialize(subject_id:, subject_namespace:)
        @subject_id = present_string(subject_id)
        @subject_namespace = present_string(subject_namespace)
      end

      def call
        return bad_request unless @subject_id && @subject_namespace

        matches = Ehr.where(subject_id: @subject_id, subject_namespace: @subject_namespace)
                     .order(:time_created, :id).to_a
        case matches.size
        when 0 then Result.new(status: :not_found, ehr_ids: [], error: "No EHR for #{subject_label}")
        when 1 then Result.new(status: :ok, ehr: matches.first, ehr_ids: [matches.first.ehr_id])
        else conflict(matches)
        end
      end

      private

      def present_string(value)
        value.is_a?(String) && !value.strip.empty? ? value : nil
      end

      def subject_label
        "subject_id=#{@subject_id} subject_namespace=#{@subject_namespace}"
      end

      def bad_request
        Result.new(status: :bad_request, ehr_ids: [],
                   error: 'subject_id and subject_namespace are required')
      end

      def conflict(matches)
        Result.new(status: :conflict, ehr_ids: matches.map(&:ehr_id),
                   error: "#{matches.size} EHRs for #{subject_label}")
      end
    end
  end
end

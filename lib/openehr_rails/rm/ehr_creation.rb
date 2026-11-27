# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Creates an EHR for POST /v1/ehr (ehr_id: nil, server-generated) and
    # PUT /v1/ehr/:ehr_id (client-supplied) -- #99, R-20261127-8.
    #
    # :conflict when
    # - the client-supplied ehr_id is already in use (ITS-REST "Create EHR
    #   with id");
    # - an EHR already has the same EHR_STATUS.subject id, namespace pair.
    #   ITS-REST "Create EHR" (POST) requires this 409; applying it to PUT as
    #   well is this implementation's own handling, so the outcome does not
    #   depend on the endpoint. ehr_ids lists the existing EHRs, oldest first,
    #   as Rm::EhrSubjectLookup does. A subject without both id and namespace
    #   (anonymous) is not compared.
    #
    # Known limitation: no unique index backs the subject check (no host
    # migration, R-20261127-8 answer 2), so two concurrent requests for the
    # same subject can both pass it.
    class EhrCreation
      Result = Struct.new(:status, :ehr, :ehr_ids, :error, keyword_init: true)

      def initialize(attributes, ehr_id: nil)
        @attributes = attributes
        @ehr_id = ehr_id
      end

      def call
        if @ehr_id && Ehr.exists?(ehr_id: @ehr_id)
          # ehr_ids stays empty: this 409's body is unchanged ({ error } only).
          return Result.new(status: :conflict, ehr_ids: [], error: "EHR #{@ehr_id} already exists")
        end

        same_subject = existing_for_subject
        return subject_conflict(same_subject) if same_subject.any?

        ehr = Ehr.create!(@attributes.merge(ehr_id: @ehr_id || SecureRandom.uuid))
        Result.new(status: :created, ehr: ehr, ehr_ids: [ehr.ehr_id])
      end

      private

      def existing_for_subject
        subject_id = @attributes[:subject_id]
        namespace = @attributes[:subject_namespace]
        return [] if subject_id.blank? || namespace.blank?

        Ehr.where(subject_id: subject_id, subject_namespace: namespace).order(:time_created, :id).pluck(:ehr_id)
      end

      def subject_conflict(ehr_ids)
        Result.new(status: :conflict, ehr_ids: ehr_ids,
                   error: "An EHR already exists for subject_id=#{@attributes[:subject_id]} " \
                          "subject_namespace=#{@attributes[:subject_namespace]}")
      end
    end
  end
end

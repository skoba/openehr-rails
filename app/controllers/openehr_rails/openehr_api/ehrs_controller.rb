# frozen_string_literal: true

module OpenehrRails
  module OpenehrApi
    # openEHR REST API EHR resource (base URL: <mount-point>/v1/ehr).
    class EhrsController < ApplicationController
      skip_forgery_protection
      # rescue_from resolves multiple matches by most-recently-declared-wins,
      # so the generic StandardError catch-all must come first.
      rescue_from StandardError, with: :render_error
      rescue_from ActiveRecord::RecordInvalid, with: :render_invalid
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      def openehr_access_scope
        :rest_api
      end

      # POST /v1/ehr  (server-generated ehr_id). 409 when an EHR already has
      # the same subject id, namespace pair (#99) -- see Rm::EhrCreation.
      def create
        render_creation(OpenehrRails::Rm::EhrCreation.new(ehr_attributes).call)
      end

      # PUT /v1/ehr/:ehr_id  (client-supplied ehr_id). 409 when the ehr_id is
      # in use, or (this implementation's own, #99) when an EHR already has
      # the same subject id, namespace pair -- see Rm::EhrCreation.
      def upsert
        render_creation(OpenehrRails::Rm::EhrCreation.new(ehr_attributes, ehr_id: params[:ehr_id]).call)
      end

      # GET /v1/ehr?subject_id=...&subject_namespace=...  (#95, "Get EHR by
      # subject id"). 200 / 404 per the specification; 409 (several EHRs for
      # the subject, with their ehr_ids) and 400 (a parameter missing) are
      # this implementation's own -- see Rm::EhrSubjectLookup.
      def by_subject
        result = OpenehrRails::Rm::EhrSubjectLookup.new(subject_id: params[:subject_id],
                                                        subject_namespace: params[:subject_namespace]).call
        return render_ehr(result.ehr) if result.status == :ok

        body = { error: result.error }
        body[:ehr_ids] = result.ehr_ids if result.status == :conflict
        render json: body, status: result.status
      end

      # GET /v1/ehr/:ehr_id
      def show
        render_ehr(find_ehr!)
      end

      # GET /v1/ehr/:ehr_id/ehr_status
      def ehr_status
        render json: OpenehrRails::Rm::EhrSerializer.new(find_ehr!).ehr_status
      end

      private

      def find_ehr!
        OpenehrRails::Rm::Ehr.find_by!(ehr_id: params[:ehr_id])
      end

      def ehr_attributes
        status = parsed_body['ehr_status'] || {}
        subject_ref = status.dig('subject', 'external_ref') || {}
        {
          subject_id: subject_ref.dig('id', 'value'),
          subject_namespace: subject_ref['namespace'],
          is_queryable: status.key?('is_queryable') ? status['is_queryable'] : true,
          is_modifiable: status.key?('is_modifiable') ? status['is_modifiable'] : true
        }.compact
      end

      def parsed_body
        @parsed_body ||= begin
          raw = request.body.read
          raw.blank? ? {} : JSON.parse(raw)
        end
      end

      def render_creation(result)
        return render_ehr(result.ehr, status: :created) if result.status == :created

        body = { error: result.error }
        body[:ehr_ids] = result.ehr_ids if result.ehr_ids.any?
        render json: body, status: result.status
      end

      def render_ehr(ehr, status: :ok)
        response.headers['Location'] = api_ehr_url(ehr.ehr_id)
        render json: OpenehrRails::Rm::EhrSerializer.new(ehr).call, status: status
      end

      def render_not_found(error)
        render json: { error: error.message }, status: :not_found
      end

      def render_invalid(error)
        render json: { error: error.message }, status: :unprocessable_entity
      end

      def render_error(error)
        log_openehr_error(error)
        render json: { error: error.message }, status: :bad_request
      end
    end
  end
end

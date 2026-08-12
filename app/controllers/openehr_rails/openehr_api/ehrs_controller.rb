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

      # POST /v1/ehr  (server-generated ehr_id)
      def create
        ehr = OpenehrRails::Rm::Ehr.create!(ehr_attributes.merge(ehr_id: SecureRandom.uuid))
        render_ehr(ehr, status: :created)
      end

      # PUT /v1/ehr/:ehr_id  (client-supplied ehr_id)
      def upsert
        if OpenehrRails::Rm::Ehr.exists?(ehr_id: params[:ehr_id])
          return render json: { error: "EHR #{params[:ehr_id]} already exists" }, status: :conflict
        end

        ehr = OpenehrRails::Rm::Ehr.create!(ehr_attributes.merge(ehr_id: params[:ehr_id]))
        render_ehr(ehr, status: :created)
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
        render json: { error: error.message }, status: :bad_request
      end
    end
  end
end

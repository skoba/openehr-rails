# frozen_string_literal: true

module OpenehrRails
  # openEHR REST API QUERY resource (base URL: <mount-point>/v1/query/aql).
  # Thin wrapper over OpenehrRails::Aql.execute (see lib/openehr_rails/aql/):
  # validate -> build Dataset from the RM graph -> execute -> RESULT_SET JSON.
  class QueriesController < ApplicationController
    skip_forgery_protection
    # rescue_from resolves multiple matches by most-recently-declared-wins,
    # so the generic StandardError catch-all must come first.
    rescue_from StandardError, with: :render_error
    rescue_from OpenehrRails::Aql::Error, with: :render_aql_error

    def openehr_access_scope
      action_name == 'execute' ? :rest_api : :admin
    end

    # GET /query -- HTML console. Executes via fetch against
    # POST /v1/query/aql below, so there is exactly one execution path.
    def show; end

    # GET  /v1/query/aql?q=...&query_parameters={"min":100}
    # POST /v1/query/aql  { "q": "...", "query_parameters": {...} }
    def execute
      q = query_text
      return render json: { error: 'q is required' }, status: :bad_request if q.blank?

      result = OpenehrRails::Aql.execute(q, params: query_parameters)
      render json: { q: q }.merge(JSON.parse(result.to_json))
    end

    private

    def query_text
      request.get? ? params[:q] : parsed_body['q']
    end

    def query_parameters
      raw = request.get? ? params[:query_parameters] : parsed_body['query_parameters']
      raw = JSON.parse(raw) if raw.is_a?(String)
      (raw || {}).to_h
    end

    def parsed_body
      @parsed_body ||= begin
        raw = request.body.read
        raw.blank? ? {} : JSON.parse(raw)
      end
    end

    def render_aql_error(error)
      status = error.is_a?(OpenehrRails::Aql::UnsupportedFeature) ? :unprocessable_entity : :bad_request
      render json: { error: error.message }, status: status
    end

    def render_error(error)
      log_openehr_error(error)
      render json: { error: error.message }, status: :bad_request
    end
  end
end

# frozen_string_literal: true

module OpenehrRails
  class ApplicationController < ActionController::Base
    layout 'openehr_rails/application'

    before_action :authenticate_openehr_access!

    # Which engine surface this request targets, so a single
    # OpenehrRails.authenticate_with hook can differentiate if desired:
    #   :admin    - template management UI, AQL console, patient timeline
    #   :rest_api - openEHR REST API under /v1
    #   :fhir     - HL7 FHIR R5 facade under /fhir
    def openehr_access_scope
      :admin
    end

    private

    def authenticate_openehr_access!
      hook = OpenehrRails.authenticate_with
      return instance_exec(&hook) if hook
      return if OpenehrRails.unauthenticated_access_allowed?

      deny_openehr_access
    end

    def log_openehr_error(error)
      Rails.logger&.error(
        "[OpenehrRails] #{error.class}: #{error.message}\n#{Array(error.backtrace).first(10).join("\n")}"
      )
    end

    def deny_openehr_access
      message = 'openEHR engine access denied: no authentication configured. ' \
                'Set OpenehrRails.authenticate_with in config/initializers/openehr.rb.'
      if request.format.json?
        render json: { error: message }, status: :forbidden
      else
        render plain: message, status: :forbidden
      end
    end
  end
end

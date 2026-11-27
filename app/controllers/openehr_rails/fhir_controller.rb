# frozen_string_literal: true

module OpenehrRails
  # HL7 FHIR R5 facade. Reads/searches/creates entry-level resources
  # (Observation, ...) by dispatching on the archetype code through
  # ResourceRegistry. Created resources are converted to openEHR RM and
  # stored canonically by the backing Storable model. Records of templates
  # registered at runtime are read from the RM graph (#101); search and read
  # are decided in Fhir::ObservationQuery.
  #
  # Mounted under the admin engine, so the FHIR base URL is
  # <mount-point>/fhir (e.g. /openehr/fhir).
  class FhirController < ApplicationController
    skip_forgery_protection
    rescue_from StandardError, with: :render_operation_outcome
    after_action :set_fhir_content_type

    FHIR_CONTENT_TYPE = 'application/fhir+json'

    def openehr_access_scope
      :fhir
    end

    def metadata
      render_fhir OpenehrRails::Fhir::CapabilityStatement.build(base_url: request.base_url)
    end

    def structure_definition
      profile = OpenehrRails::Fhir::ProfileRepository.find(params[:id])
      return render_not_found('StructureDefinition', params[:id]) unless profile

      render_fhir profile
    end

    # GET /fhir/Observation?code=<archetype_id>&subject=<id>
    def search
      observations = OpenehrRails::Fhir::ObservationQuery.new(code: params[:code], subject: params[:subject]).search

      render_fhir(searchset_bundle(observations))
    end

    # GET /fhir/Observation/:id  (id = "<recordId>-<archetypeSlug>", or
    # "c<uuid hex>-<entry index>" for a runtime record)
    def show
      observation = OpenehrRails::Fhir::ObservationQuery.find(params[:id])
      return render_not_found('Observation', params[:id]) unless observation

      render_fhir observation
    end

    # POST /fhir/Observation
    def create
      resource = parse_body
      code = resource.dig('code', 'coding', 0, 'code')
      entry = OpenehrRails::Fhir::ObservationQuery.creatable_entry(code)

      attrs = OpenehrRails::Fhir::Deserializer.new(entry.model, resource).attributes
      record = entry.model.create!(attrs)
      observation = OpenehrRails::Fhir::Serializer.new(record).observations
                                                  .find { |o| o[:code][:coding].first[:code] == code }

      response.headers['Location'] = "#{request.path}/#{observation[:id]}"
      render_fhir(observation, status: :created)
    end

    private

    def parse_body
      raw = request.body.read
      raw.blank? ? {} : JSON.parse(raw)
    end

    def searchset_bundle(observations)
      {
        resourceType: 'Bundle',
        type: 'searchset',
        total: observations.size,
        entry: observations.map { |o| { resource: o } }
      }
    end

    def render_fhir(resource, status: :ok)
      render json: resource, status: status
    end

    def set_fhir_content_type
      response.content_type = FHIR_CONTENT_TYPE
    end

    def render_not_found(type, id)
      render_fhir(operation_outcome('not-found', "#{type}/#{id} not found"), status: :not_found)
    end

    def render_operation_outcome(error)
      log_openehr_error(error)
      status = case error
               when OpenehrRails::Fhir::Deserializer::UnmappedResource then :unprocessable_entity
               when ActiveRecord::RecordInvalid then :unprocessable_entity
               when OpenehrRails::Fhir::TemplateSourceError then :internal_server_error
               else :bad_request
               end
      render_fhir(operation_outcome('processing', error.message), status: status)
    end

    def operation_outcome(code, diagnostics)
      {
        resourceType: 'OperationOutcome',
        issue: [{ severity: 'error', code: code, diagnostics: diagnostics }]
      }
    end
  end
end

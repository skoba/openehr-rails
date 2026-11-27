# frozen_string_literal: true

module OpenehrRails
  # HL7 FHIR R5 facade. Reads/searches/creates entry-level resources
  # (Observation, ...) by dispatching on the archetype code through
  # ResourceRegistry. Created resources are converted to openEHR RM and
  # stored canonically by the backing Storable model. Records of templates
  # registered at runtime are read from the RM graph (#101); search and read
  # are decided in Fhir::ResourceQuery.
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
    # GET /fhir/Condition?category=<archetype_id>&subject=<id>  (#104)
    # The archetype is matched on the element that carries its coding.
    def search
      resources = OpenehrRails::Fhir::ResourceQuery.new(resource_type: resource_type,
                                                        archetype_id: params[archetype_param],
                                                        subject: params[:subject]).search

      render_fhir(searchset_bundle(resources))
    end

    # GET /fhir/<Type>/:id  (id = "<recordId>-<archetypeSlug>", or
    # "c<uuid hex>-<entry index>" for a runtime record)
    def show
      resource = OpenehrRails::Fhir::ResourceQuery.find(params[:id], resource_type: resource_type)
      return render_not_found(resource_type, params[:id]) unless resource

      render_fhir resource
    end

    # POST /fhir/Observation
    def create
      resource = parse_body
      code = resource.dig('code', 'coding', 0, 'code')
      entry = OpenehrRails::Fhir::ResourceQuery.creatable_entry(code)

      attrs = OpenehrRails::Fhir::Deserializer.new(entry.model, resource).attributes
      record = entry.model.create!(attrs)
      observation = OpenehrRails::Fhir::Serializer.new(record).observations
                                                  .find { |o| o[:code][:coding].first[:code] == code }

      response.headers['Location'] = "#{request.path}/#{observation[:id]}"
      render_fhir(observation, status: :created)
    end

    private

    # Set by the routes (defaults: { resource_type: ... }).
    def resource_type
      params[:resource_type] || 'Observation'
    end

    def archetype_param
      OpenehrRails::Fhir::CapabilityStatement.archetype_search_param(resource_type)
    end

    def parse_body
      raw = request.body.read
      raw.blank? ? {} : JSON.parse(raw)
    end

    def searchset_bundle(resources)
      {
        resourceType: 'Bundle',
        type: 'searchset',
        total: resources.size,
        entry: resources.map { |resource| { resource: resource } }
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

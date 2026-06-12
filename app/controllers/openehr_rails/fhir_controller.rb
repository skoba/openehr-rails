# frozen_string_literal: true

module OpenehrRails
  # HL7 FHIR R5 facade. Reads/searches/creates entry-level resources
  # (Observation, ...) by dispatching on the archetype code through
  # ResourceRegistry. Created resources are converted to openEHR RM and
  # stored canonically by the backing Storable model.
  #
  # Mounted under the admin engine, so the FHIR base URL is
  # <mount-point>/fhir (e.g. /openehr/fhir).
  class FhirController < ApplicationController
    skip_forgery_protection
    rescue_from StandardError, with: :render_operation_outcome
    after_action :set_fhir_content_type

    FHIR_CONTENT_TYPE = 'application/fhir+json'

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
      entries = lookup_entries(params[:code])
      records = entries.flat_map { |entry| scoped_records(entry) }.uniq
      observations = records.flat_map { |record| OpenehrRails::Fhir::Serializer.new(record).observations }
      observations = filter_by_code(observations, params[:code])

      render_fhir(searchset_bundle(observations))
    end

    # GET /fhir/Observation/:id  (id = "<recordId>-<archetypeSlug>")
    def show
      record, entry = resolve(params[:id])
      return render_not_found('Observation', params[:id]) unless record

      observation = OpenehrRails::Fhir::Serializer.new(record).observations
                                                  .find { |o| o[:id] == params[:id] }
      return render_not_found('Observation', params[:id]) unless observation

      render_fhir observation
    end

    # POST /fhir/Observation
    def create
      resource = parse_body
      code = resource.dig('code', 'coding', 0, 'code')
      entry = OpenehrRails::Fhir::ResourceRegistry.find_by_code(code)
      raise OpenehrRails::Fhir::Deserializer::UnmappedResource, "unknown code #{code.inspect}" unless entry

      attrs = OpenehrRails::Fhir::Deserializer.new(entry.model, resource).attributes
      record = entry.model.create!(attrs)
      observation = OpenehrRails::Fhir::Serializer.new(record).observations
                                                  .find { |o| o[:code][:coding].first[:code] == code }

      response.headers['Location'] = "#{request.path}/#{observation[:id]}"
      render_fhir(observation, status: :created)
    end

    private

    def lookup_entries(code)
      return OpenehrRails::Fhir::ResourceRegistry.entries unless code

      # NOTE: Array() would splat the Entry struct into its members.
      entry = OpenehrRails::Fhir::ResourceRegistry.find_by_code(code)
      entry ? [entry] : []
    end

    def scoped_records(entry)
      relation = entry.model.all
      if params[:subject].present?
        ehr_id = params[:subject].split('/').last
        relation = relation.where(ehr_id: ehr_id)
      end
      relation.to_a
    end

    def filter_by_code(observations, code)
      return observations unless code

      observations.select { |o| o[:code][:coding].first[:code] == code }
    end

    def resolve(id)
      slug = id.split('-', 2).last
      entry = OpenehrRails::Fhir::ResourceRegistry.find_by_slug(slug)
      return [nil, nil] unless entry

      record_id = id.split('-', 2).first
      [entry.model.find_by(id: record_id), entry]
    end

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
      status = case error
               when OpenehrRails::Fhir::Deserializer::UnmappedResource then :unprocessable_entity
               when ActiveRecord::RecordInvalid then :unprocessable_entity
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

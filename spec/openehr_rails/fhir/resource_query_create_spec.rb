# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../storable_spec_model'

# #111: POST /fhir/Observation (FhirController#create, which calls
# ResourceQuery.create). A POST that maps to no value used to create a record
# with every value nil and then answer 400 (NoMethodError on the missing
# Observation). It is now refused with 422 before anything is created.
describe OpenehrRails::Fhir::ResourceQuery do
  def bmi_code = 'openEHR-EHR-OBSERVATION.body_mass_index.v2'
  def height_code = 'openEHR-EHR-OBSERVATION.height.v2'

  around do |example|
    saved_models = OpenehrRails::Fhir::ResourceRegistry.model_names.dup
    OpenehrRails::Fhir::ResourceRegistry.reset!
    OpenehrRails::Fhir::ResourceRegistry.register_model('BmiCalculation')
    OpenehrRails::Fhir.template_source = -> { [] }
    example.run
  ensure
    OpenehrRails::Fhir.template_source = nil
    OpenehrRails::Fhir::ResourceRegistry.reset!
    saved_models.each { |name| OpenehrRails::Fhir::ResourceRegistry.register_model(name) }
  end

  def observation(code, **values)
    { 'resourceType' => 'Observation', 'status' => 'final',
      'code' => { 'coding' => [{ 'system' => 'http://openehr.org/ckm/archetypes', 'code' => code }] },
      'subject' => { 'reference' => 'Patient/ehr-1' } }.merge(values.transform_keys(&:to_s))
  end

  describe '.create' do
    it 'refuses a multi-leaf POST with no component[] and creates nothing' do # bug
      resource = observation(bmi_code, valueQuantity: { 'value' => 22.5, 'unit' => 'kg/m2' })

      expect { described_class.create(resource) }
        .to raise_error(OpenehrRails::Fhir::Deserializer::UnmappedResource, /component\[\]/)
        .and(not_change(BmiCalculation, :count))
    end

    it 'refuses a POST whose components map to no element and creates nothing' do # bug
      resource = observation(bmi_code, component: [{ 'code' => { 'coding' => [{ 'code' => 'unknown' }] },
                                                     'valueQuantity' => { 'value' => 1 } }])

      expect { described_class.create(resource) }
        .to raise_error(OpenehrRails::Fhir::Deserializer::UnmappedResource, /no value/)
        .and(not_change(BmiCalculation, :count))
    end

    it 'creates a single-leaf POST (height) and returns its Observation' do # regression pin
      resource = observation(height_code, valueQuantity: { 'value' => 181.5, 'unit' => 'cm' })

      created = nil
      expect { created = described_class.create(resource) }.to change(BmiCalculation, :count).by(1)
      expect(created).to include(resourceType: 'Observation', valueQuantity: include(value: 181.5))
      expect(created[:id]).to eq("#{BmiCalculation.last.id}-openehr-observation-height-v2")
    end

    it 'creates a multi-leaf POST that sends component[]' do # regression pin
      resource = observation(bmi_code, component: [
                               { 'code' => { 'coding' => [{ 'code' => "#{bmi_code}#at0004" }] },
                                 'valueQuantity' => { 'value' => 22.5, 'unit' => 'kg/m2' } }
                             ])

      expect { described_class.create(resource) }.to change(BmiCalculation, :count).by(1)
      expect(BmiCalculation.last.body_mass_index).to eq(22.5)
    end
  end
end

RSpec::Matchers.define_negated_matcher :not_change, :change

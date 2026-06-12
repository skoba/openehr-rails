# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../storable_spec_model'

describe OpenehrRails::Fhir::Serializer do
  let(:record) { BmiCalculation.create!(height: 170.0, body_weight: 65.0, ehr_id: 'patient-1') }
  let(:observations) { described_class.new(record).observations }

  it 'emits one Observation per entry that has data' do
    expect(observations.size).to eq(2)
    expect(observations.map { |o| o[:resourceType] }.uniq).to eq(['Observation'])
  end

  describe 'the height observation' do
    subject(:observation) do
      observations.find do |o|
        o[:code][:coding].first[:code] == 'openEHR-EHR-OBSERVATION.height.v2'
      end
    end

    it 'is final and coded by archetype' do
      expect(observation[:status]).to eq('final')
      coding = observation[:code][:coding].first
      expect(coding[:system]).to eq('http://openehr.org/ckm/archetypes')
    end

    it 'references the subject from ehr_id' do
      expect(observation[:subject]).to eq(reference: 'Patient/patient-1')
    end

    it 'carries the value as a Quantity' do
      expect(observation[:valueQuantity]).to eq(
        value: 170.0, unit: 'cm', system: 'http://unitsofmeasure.org', code: 'cm'
      )
    end

    it 'has a stable id encoding the record and archetype' do
      expect(observation[:id]).to eq("#{record.id}-openehr-observation-height-v2")
    end

    it 'sets effectiveDateTime from composed_at' do
      expect(observation[:effectiveDateTime]).to eq(record.composed_at.iso8601)
    end
  end

  it 'skips entries with no data' do
    record = BmiCalculation.create!(height: 158.0)
    obs = described_class.new(record).observations
    expect(obs.size).to eq(1)
    expect(obs.first[:code][:coding].first[:code]).to eq('openEHR-EHR-OBSERVATION.height.v2')
  end
end

# Regression: scaffolded models emit FIELD_MAP keyed by name with the
# :name key stripped from each field hash.
class GeneratedStyleBmi < ActiveRecord::Base
  self.table_name = 'bmi_calculations'
  include OpenehrRails::Storable

  TEMPLATE_ID = 'bmi_calculation'
  ROOT_ARCHETYPE_ID = 'openEHR-EHR-COMPOSITION.report-result.v1'
  FIELD_MAP = BmiCalculation::FIELD_MAP.transform_values { |f| f.except(:name) }.freeze
end

describe 'generated-style FIELD_MAP (no :name key)' do
  it 'serializes and deserializes through the name-normalized registry' do
    record = GeneratedStyleBmi.create!(height: 160.0, ehr_id: 'p1')
    observations = OpenehrRails::Fhir::Serializer.new(record).observations
    expect(observations.first[:valueQuantity][:value]).to eq(160.0)

    attrs = OpenehrRails::Fhir::Deserializer.new(GeneratedStyleBmi, {
      'resourceType' => 'Observation',
      'code' => { 'coding' => [{ 'code' => 'openEHR-EHR-OBSERVATION.height.v2' }] },
      'valueQuantity' => { 'value' => 150.0 }
    }).attributes
    expect(attrs[:height]).to eq(150.0)
  end

  it 'still builds the canonical RM composition' do
    record = GeneratedStyleBmi.create!(height: 160.0)
    expect(record.rm_composition['content'].first
                 .dig('data', 'events', 0, 'data', 'items', 0, 'value', 'magnitude')).to eq(160.0)
  end
end

describe OpenehrRails::Fhir::Deserializer do
  let(:observation) do
    {
      'resourceType' => 'Observation',
      'status' => 'final',
      'code' => {
        'coding' => [
          { 'system' => 'http://openehr.org/ckm/archetypes',
            'code' => 'openEHR-EHR-OBSERVATION.height.v2' }
        ]
      },
      'subject' => { 'reference' => 'Patient/patient-9' },
      'valueQuantity' => { 'value' => 181.5, 'unit' => 'cm' }
    }
  end

  it 'maps a FHIR Observation to model attributes' do
    attrs = described_class.new(BmiCalculation, observation).attributes
    expect(attrs).to include(height: 181.5, ehr_id: 'patient-9')
  end

  it 'round-trips through the model into a canonical RM composition' do
    attrs = described_class.new(BmiCalculation, observation).attributes
    record = BmiCalculation.create!(attrs)

    expect(record.rm_composition['_type']).to eq('COMPOSITION')
    height_entry = record.rm_composition['content']
                         .find { |e| e['archetype_node_id'] == 'openEHR-EHR-OBSERVATION.height.v2' }
    expect(height_entry.dig('data', 'events', 0, 'data', 'items', 0, 'value', 'magnitude'))
      .to eq(181.5)
  end

  it 'raises when no field maps to the observation code' do
    bad = observation.merge('code' => { 'coding' => [{ 'code' => 'unknown' }] })
    expect { described_class.new(BmiCalculation, bad).attributes }
      .to raise_error(OpenehrRails::Fhir::Deserializer::UnmappedResource)
  end
end

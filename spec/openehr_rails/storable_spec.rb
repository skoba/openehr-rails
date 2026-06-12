# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# Mirrors the model that `rails g openehr:scaffold bmi_calculation.opt`
# generates; the backing table is defined in spec/support/active_record.rb.
class BmiCalculation < ActiveRecord::Base
  include OpenehrRails::Storable
  include OpenehrRails::AqlQueryable

  TEMPLATE_ID = 'bmi_calculation'
  ROOT_ARCHETYPE_ID = 'openEHR-EHR-COMPOSITION.report-result.v1'
  FIELD_MAP = OpenehrRails::Opt::FieldExtractor.new(
    OpenehrRails::Opt.parse(
      File.expand_path('../generators/templates/bmi_calculation.opt', __dir__)
    )
  ).fields.to_h { |field| [field[:name], field] }.freeze
end

describe OpenehrRails::Storable do
  let(:record) { BmiCalculation.new(height: 170.0, body_weight: 65.0) }

  describe 'saving' do
    before { record.save! }

    it 'fills composition defaults' do
      expect(record.uid).to be_present
      expect(record.composed_at).to be_present
      expect(record.template_id).to eq('bmi_calculation')
    end

    it 'persists the canonical RM composition' do
      composition = record.reload.rm_composition

      expect(composition['_type']).to eq('COMPOSITION')
      expect(composition.dig('archetype_details', 'template_id', 'value'))
        .to eq('bmi_calculation')
      expect(composition['archetype_node_id'])
        .to eq('openEHR-EHR-COMPOSITION.report-result.v1')
    end

    it 'stores one entry per archetype with data' do
      content = record.reload.rm_composition['content']

      expect(content.map { |e| e['archetype_node_id'] }).to contain_exactly(
        'openEHR-EHR-OBSERVATION.height.v2',
        'openEHR-EHR-OBSERVATION.body_weight.v2'
      )
      expect(content.map { |e| e['_type'] }.uniq).to eq(['OBSERVATION'])
    end

    it 'nests the value at the RM path' do
      height_entry = record.reload.rm_composition['content']
                           .find { |e| e['archetype_node_id'] == 'openEHR-EHR-OBSERVATION.height.v2' }

      element = height_entry.dig('data', 'events', 0, 'data', 'items', 0)
      expect(element['_type']).to eq('ELEMENT')
      expect(element['archetype_node_id']).to eq('at0004')
      expect(element['value']).to eq(
        '_type' => 'DV_QUANTITY', 'magnitude' => 170.0, 'units' => 'cm'
      )
    end
  end

  describe '.from_rm_composition' do
    it 'round-trips attribute values' do
      record.save!
      restored = BmiCalculation.from_rm_composition(record.reload.rm_composition)

      expect(restored.height).to eq(170.0)
      expect(restored.body_weight).to eq(65.0)
      expect(restored.body_mass_index).to be_nil
    end
  end
end

describe OpenehrRails::AqlQueryable do
  let(:height_path) do
    '/content[openEHR-EHR-OBSERVATION.height.v2]' \
      '/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value'
  end

  before { BmiCalculation.create!(height: 158.0) }

  it 'resolves an RM path to the backing column' do
    expect(BmiCalculation.column_for_path(height_path)).to eq('height')
  end

  it 'queries by RM path' do
    expect(BmiCalculation.find_by_path(height_path, 158.0).count).to eq(1)
  end

  it 'raises for unknown paths' do
    expect { BmiCalculation.find_by_path('/content[nowhere]/value', 1) }
      .to raise_error(ArgumentError, /no field maps/)
  end
end

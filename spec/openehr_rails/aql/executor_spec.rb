# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'

describe OpenehrRails::Aql::Executor do
  let(:height_query) do
    'SELECT o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude AS height ' \
      'FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2]'
  end

  it 'executes a query against the RM graph and returns matching rows' do
    BmiCalculation.create!(height: 170.0)

    result = described_class.execute(height_query)

    expect(result.rows).to eq([[170.0]])
  end

  it 'binds query parameters' do
    BmiCalculation.create!(height: 170.0)
    BmiCalculation.create!(height: 180.0)
    query = "#{height_query} WHERE o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude > $min"

    result = described_class.execute(query, params: { 'min' => 175.0 })

    expect(result.rows).to eq([[180.0]])
  end

  it 'raises InvalidQuery when a bound parameter is missing' do
    BmiCalculation.create!(height: 170.0)
    query = "#{height_query} WHERE o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude > $min"

    expect { described_class.execute(query) }.to raise_error(OpenehrRails::Aql::InvalidQuery)
  end

  it 'raises UnsupportedFeature for a query the validator rejects, without touching the dataset' do
    query = "SELECT c FROM EHR e CONTAINS COMPOSITION c WHERE c/archetype_node_id LIKE 'foo%'"

    expect { described_class.execute(query) }.to raise_error(OpenehrRails::Aql::UnsupportedFeature, /LIKE/)
  end

  describe 'OpenehrRails::Aql.execute (module-level convenience API)' do
    it 'delegates to Executor' do
      BmiCalculation.create!(height: 170.0)

      expect(OpenehrRails::Aql.execute(height_query).rows).to eq([[170.0]])
    end
  end
end

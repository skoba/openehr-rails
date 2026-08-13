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
    query = 'SELECT v FROM EHR e CONTAINS VERSIONED_COMPOSITION v'

    expect { described_class.execute(query) }
      .to raise_error(OpenehrRails::Aql::UnsupportedFeature, /VERSIONED_COMPOSITION/)
  end

  describe 'constructs newly executable since openehr 2.3.0 (real RM-graph data)' do
    it 'executes a LIKE query using AQL glob syntax (not SQL %/_)' do
      BmiCalculation.create!(height: 170.0)
      query = 'SELECT c/name/value FROM EHR e CONTAINS COMPOSITION c ' \
              "WHERE c/name/value LIKE 'openEHR-EHR-COMPOSITION.*'"

      result = described_class.execute(query)

      expect(result.rows).to eq([['openEHR-EHR-COMPOSITION.report-result.v1']])
    end

    it 'executes a MATCHES query against a literal value list' do
      BmiCalculation.create!(height: 170.0)
      query = 'SELECT c/name/value FROM EHR e CONTAINS COMPOSITION c ' \
              "WHERE c/name/value MATCHES {'openEHR-EHR-COMPOSITION.report-result.v1', 'other'}"

      result = described_class.execute(query)

      expect(result.rows).to eq([['openEHR-EHR-COMPOSITION.report-result.v1']])
    end

    it 'executes a CONTAINS nodePredicate ([at-code]) form, not just the archetype predicate form' do
      BmiCalculation.create!(height: 170.0)
      # at0004 is the ELEMENT node_id the height value lives under
      # (see height_query's "items[at0004]/value/magnitude" path above) --
      # a nodePredicate on CONTAINS ELEMENT, not the archetype-id predicate.
      query = 'SELECT e/value/magnitude FROM EHR ehr ' \
              'CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2] ' \
              'CONTAINS ELEMENT e[at0004]'

      result = described_class.execute(query)

      expect(result.rows).to eq([[170.0]])
    end

    it 'executes a SELECT mixing a plain column with an aggregate (implicit GROUP BY)' do
      BmiCalculation.create!(height: 170.0)
      query = 'SELECT c/name/value, COUNT(c) FROM EHR e CONTAINS COMPOSITION c'

      result = described_class.execute(query)

      expect(result.rows).to eq([['openEHR-EHR-COMPOSITION.report-result.v1', 1]])
    end
  end

  describe 'OpenehrRails::Aql.execute (module-level convenience API)' do
    it 'delegates to Executor' do
      BmiCalculation.create!(height: 170.0)

      expect(OpenehrRails::Aql.execute(height_query).rows).to eq([[170.0]])
    end
  end
end

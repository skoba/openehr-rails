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

  # skoba/openehr-rails#44 (a) bug, end to end: the store also holds a
  # composition whose to_rm fails (synthetic SECTION graph, see
  # dataset_adapter_spec.rb); a query on an unrelated template must still
  # return its rows.
  describe 'with a composition whose to_rm fails in the store' do
    before do
      BmiCalculation.create!(height: 170.0)
      # ITEM_TABLE stays outside RmObjectBuilder::TYPE_CLASSES after #45
      # made SECTION buildable (ruling condition (c)).
      OpenehrRails::Rm::CompositionCommitter.commit(
        {
          '_type' => 'COMPOSITION',
          'archetype_node_id' => 'openEHR-EHR-COMPOSITION.synthetic_table_test.v1',
          'content' => [
            {
              '_type' => 'EVALUATION', 'archetype_node_id' => 'openEHR-EHR-EVALUATION.synthetic_table_test.v1',
              'archetype_details' => { 'archetype_id' => { 'value' => 'openEHR-EHR-EVALUATION.synthetic_table_test.v1' } },
              'data' => { '_type' => 'ITEM_TABLE', 'archetype_node_id' => 'at0001', 'rows' => [] }
            }
          ]
        },
        uid: 'uid-table-exec'
      )
    end

    it 'still answers a query on another template, skipping the broken composition' do
      rows = nil

      expect { rows = described_class.execute(height_query).rows }.to output(/uid-table-exec/).to_stderr

      expect(rows).to eq([[170.0]])
    end
  end

  # skoba/openehr-rails#45 (b) enhancement, end to end: values under
  # INSTRUCTION.protocol / activities and inside a SECTION are reachable by
  # AQL once the builder rebuilds those nodes. Same synthetic fixture as
  # rm_object_builder_spec.rb.
  describe 'INSTRUCTION and SECTION paths (#45)' do
    before do
      OpenehrRails::Rm::CompositionCommitter.commit(SyntheticReferralCanonicalHash.composition, uid: 'uid-referral-aql')
    end

    it 'reaches an ACTIVITY description leaf through i/activities[...]/description[...]' do
      query = 'SELECT i/activities[at0001]/description[at0009]/items[at0121]/value/value ' \
              'FROM EHR e CONTAINS COMPOSITION c ' \
              "CONTAINS INSTRUCTION i[#{SyntheticReferralCanonicalHash::INSTRUCTION_ID}]"

      expect(described_class.execute(query).rows).to eq([['Chest pain work-up']])
    end

    it 'reaches a protocol leaf through i/protocol[...]' do
      query = 'SELECT i/protocol[at0008]/items[at0010]/value/value ' \
              'FROM EHR e CONTAINS COMPOSITION c ' \
              "CONTAINS INSTRUCTION i[#{SyntheticReferralCanonicalHash::INSTRUCTION_ID}]"

      expect(described_class.execute(query).rows).to eq([['Synthetic Hospital']])
    end

    it 'reaches an EVALUATION nested in a SECTION' do
      query = 'SELECT ev/data[at0001]/items[at0002]/value/value ' \
              'FROM EHR e CONTAINS COMPOSITION c ' \
              "CONTAINS EVALUATION ev[#{SyntheticReferralCanonicalHash::EVALUATION_ID}]"

      expect(described_class.execute(query).rows).to eq([['stable']])
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'

# openehr ~> 2.0's AQL engine contract (per the gem's own README/CHANGELOG)
# recommends feeding OpenEHR::AQL::Dataset with RM objects built via
# OpenEHR::RM::CompositionFactory.create_from_json(canonical_json). That
# factory only converts Hash-valued attributes (Factory.params walks
# each_with_object over a Hash); array-valued attributes (content/events/
# items/...) are left as raw Hashes instead of being recursively converted.
#
# The Dataset boundary (OpenEHR::AQL::Dataset#each_ehr) only checks that each
# top-level *composition* is_a?(Pathable) -- Composition itself is Pathable,
# so that check passes even though its content is Hashes underneath. The AQL
# engine's CONTAINS traversal then finds nothing to descend into and the
# query silently returns zero rows, with no error anywhere.
#
# This spec pins that behaviour (against a real query, not just a class
# check) so a future openehr upgrade that fixes create_from_json is noticed
# here (these expectations start failing), and documents why the AQL
# integration must build its Dataset from the RM graph
# (OpenehrRails::Rm::Composition#to_rm via RmObjectBuilder) rather than from
# the rm_composition JSON cache.
describe 'feeding OpenEHR::AQL::Dataset from a Composition built via create_from_json' do
  let(:json) do
    {
      '_type' => 'COMPOSITION',
      'archetype_node_id' => 'openEHR-EHR-COMPOSITION.report-result.v1',
      'name' => { '_type' => 'DV_TEXT', 'value' => 'test' },
      'language' => { '_type' => 'CODE_PHRASE',
                      'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'ISO_639-1' }, 'code_string' => 'en' },
      'territory' => { '_type' => 'CODE_PHRASE',
                       'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'ISO_3166-1' }, 'code_string' => 'US' },
      'category' => { '_type' => 'DV_CODED_TEXT', 'value' => 'event',
                      'defining_code' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'openehr' }, 'code_string' => '433' } },
      'composer' => { '_type' => 'PARTY_IDENTIFIED', 'name' => 'unknown' },
      'content' => [
        {
          '_type' => 'OBSERVATION', 'archetype_node_id' => 'openEHR-EHR-OBSERVATION.height.v2',
          'name' => { '_type' => 'DV_TEXT', 'value' => 'Height' },
          'language' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'ISO_639-1' }, 'code_string' => 'en' },
          'encoding' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'IANA_character-sets' }, 'code_string' => 'UTF-8' },
          'subject' => { '_type' => 'PARTY_SELF' },
          'data' => {
            '_type' => 'HISTORY', 'origin' => { '_type' => 'DV_DATE_TIME', 'value' => '2026-01-01T00:00:00' },
            'events' => [
              {
                '_type' => 'POINT_EVENT', 'time' => { '_type' => 'DV_DATE_TIME', 'value' => '2026-01-01T00:00:00' },
                'data' => {
                  '_type' => 'ITEM_TREE',
                  'items' => [
                    {
                      '_type' => 'ELEMENT', 'archetype_node_id' => 'at0004',
                      'name' => { '_type' => 'DV_TEXT', 'value' => 'Height' },
                      'value' => { '_type' => 'DV_QUANTITY', 'magnitude' => 170.0, 'units' => 'cm' }
                    }
                  ]
                }
              }
            ]
          }
        }
      ]
    }
  end

  let(:query) do
    'SELECT o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude AS height ' \
      'FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2]'
  end

  it 'leaves array-valued attributes (content) as raw Hashes, not RM objects' do
    composition = OpenEHR::RM::CompositionFactory.create_from_json(json.to_json)

    expect(composition.content.first).to be_a(Hash)
    expect(composition.content.first).not_to be_a(OpenEHR::RM::Common::Archetyped::Pathable)
  end

  it 'passes the Dataset boundary check anyway (only the top-level composition is checked)' do
    composition = OpenEHR::RM::CompositionFactory.create_from_json(json.to_json)

    expect do
      OpenEHR::AQL::Dataset.new(ehrs: [{ ehr_id: 'e1', compositions: [composition] }]).each_ehr { |_ehr| }
    end.not_to raise_error
  end

  it 'therefore returns zero rows from a query that should match' do
    composition = OpenEHR::RM::CompositionFactory.create_from_json(json.to_json)
    dataset = OpenEHR::AQL::Dataset.new(ehrs: [{ ehr_id: 'e1', compositions: [composition] }])

    expect(OpenEHR::AQL.execute(query, dataset).rows).to eq([])
  end

  it 'the RM graph path (Rm::Composition#to_rm) does not have this gap and returns the match' do
    record = BmiCalculation.create!(height: 170.0)
    dataset = OpenEHR::AQL::Dataset.new(ehrs: [{ ehr_id: 'e1', compositions: [record.rm_graph.to_rm] }])

    expect(OpenEHR::AQL.execute(query, dataset).rows).to eq([[170.0]])
  end
end

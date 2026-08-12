# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'

# openehr 2.0.0 had a bug where OpenEHR::RM::CompositionFactory.create_from_json
# didn't recursively convert array-valued attributes (content/events/items/...)
# into RM objects (Factory.params only handled Hash values), so a composition's
# #content stayed an Array of raw Hashes -- CONTAINS traversal found nothing to
# descend into and AQL queries silently returned zero rows, with no error
# anywhere (filed as doc/HANDOFF_openehr_aql_create_from_json.md).
#
# Fixed upstream in openehr 2.0.1: this spec now pins the FIXED behaviour
# (given fully RM-conformant canonical JSON -- every LOCATABLE needs a
# mandatory `name`, which this hand-built fixture supplies but which
# Storable's own canonical JSON does not populate for structural nodes like
# HISTORY/POINT_EVENT/ITEM_TREE) as a regression guard.
#
# Fixed upstream again in openehr 2.0.2: Factory.params/convert_value no
# longer crashes on _type-less non-polymorphic Hashes (ARCHETYPED's
# archetype_id/template_id, CODE_PHRASE's terminology_id), which is exactly
# the shape Storable's own canonical JSON uses (doc/HANDOFF_openehr_factory_
# missing_type.md).
#
# create_from_json is still not used as OpenehrRails::Aql::DatasetAdapter's
# feed, though: Storable's own rm_composition JSON omits `name` on structural
# nodes like HISTORY/POINT_EVENT/ITEM_TREE (RmObjectBuilder papers over this
# by synthesizing a name from archetype_node_id when none is stored), so
# create_from_json still raises ArgumentError ("name should not be empty")
# on real scaffolded data -- now the ONLY remaining gap, and it's on the
# openehr-rails side, not openehr-ruby's. The RM graph path
# (Rm::Composition#to_rm via RmObjectBuilder) remains DatasetAdapter's feed;
# the last example below documents why.
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
            '_type' => 'HISTORY', 'archetype_node_id' => 'at0001',
            'name' => { '_type' => 'DV_TEXT', 'value' => 'History' },
            'origin' => { '_type' => 'DV_DATE_TIME', 'value' => '2026-01-01T00:00:00' },
            'events' => [
              {
                '_type' => 'POINT_EVENT', 'archetype_node_id' => 'at0002',
                'name' => { '_type' => 'DV_TEXT', 'value' => 'Any event' },
                'time' => { '_type' => 'DV_DATE_TIME', 'value' => '2026-01-01T00:00:00' },
                'data' => {
                  '_type' => 'ITEM_TREE', 'archetype_node_id' => 'at0003',
                  'name' => { '_type' => 'DV_TEXT', 'value' => 'Tree' },
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

  it 'recursively converts array-valued attributes (content) into real RM objects' do
    composition = OpenEHR::RM::CompositionFactory.create_from_json(json.to_json)

    expect(composition.content.first).to be_a(OpenEHR::RM::Composition::Content::Entry::Observation)
    expect(composition.content.first).to be_a(OpenEHR::RM::Common::Archetyped::Pathable)
  end

  it 'is therefore usable to feed the AQL Dataset boundary directly' do
    composition = OpenEHR::RM::CompositionFactory.create_from_json(json.to_json)

    expect do
      OpenEHR::AQL::Dataset.new(ehrs: [{ ehr_id: 'e1', compositions: [composition] }]).each_ehr { |_ehr| }
    end.not_to raise_error
  end

  it 'and a query against it returns the matching row (not silently empty)' do
    composition = OpenEHR::RM::CompositionFactory.create_from_json(json.to_json)
    dataset = OpenEHR::AQL::Dataset.new(ehrs: [{ ehr_id: 'e1', compositions: [composition] }])

    expect(OpenEHR::AQL.execute(query, dataset).rows).to eq([[170.0]])
  end

  it 'still cannot round-trip real Storable output (missing `name` on structural nodes it never wrote)' do
    record = BmiCalculation.create!(height: 170.0)

    # As of 2.0.2 the _type-less archetype_id/template_id/terminology_id gap
    # is fixed upstream, so this now fails for the one remaining (and
    # openehr-rails-side) reason: ArgumentError "name should not be empty"
    # on a structural node such as HISTORY/POINT_EVENT/ITEM_TREE. Kept as a
    # generic StandardError match since the exact node/message is this
    # library's own implementation detail, not a contract to pin exactly.
    expect { OpenEHR::RM::CompositionFactory.create_from_json(record.rm_composition.to_json) }
      .to raise_error(StandardError)
  end

  it 'so DatasetAdapter keeps using the RM graph path (Rm::Composition#to_rm), which has no such gap' do
    record = BmiCalculation.create!(height: 170.0)
    dataset = OpenEHR::AQL::Dataset.new(ehrs: [{ ehr_id: 'e1', compositions: [record.rm_graph.to_rm] }])

    expect(OpenEHR::AQL.execute(query, dataset).rows).to eq([[170.0]])
  end
end

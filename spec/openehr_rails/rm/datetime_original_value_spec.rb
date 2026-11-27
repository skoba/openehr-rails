# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'

# #63 (R-20261126-14): a DV_DATE_TIME value keeps the ISO 8601 string it was
# committed with -- partial precision and UTC offset included -- through the
# RM graph. The original string lives in the row's text_value (plan A of
# docs/design/63-datetime-precision-plan.md: no new column, no migration);
# datetime_value stays the normalized instant used for SQL and ordering.
#
# AQL keeps receiving the normalized UTC value until the upstream
# DvDateTime#magnitude offset fix is released (R-20261126-14 answer 2).
# rubocop:disable-next RSpec/DescribeClass -- the behavior spans GraphBuilder, CanonicalSerializer, RmObjectBuilder and the AQL adapter
describe 'DV_DATE_TIME original value (#63)' do
  def canonical_with(value)
    {
      '_type' => 'COMPOSITION',
      'archetype_node_id' => 'openEHR-EHR-COMPOSITION.invented_dt.v1',
      'archetype_details' => {
        '_type' => 'ARCHETYPED',
        'archetype_id' => { 'value' => 'openEHR-EHR-COMPOSITION.invented_dt.v1' },
        'template_id' => { 'value' => 'invented_dt' },
        'rm_version' => '1.0.4'
      },
      'content' => [
        {
          '_type' => 'EVALUATION',
          'archetype_node_id' => 'openEHR-EHR-EVALUATION.invented_dt.v1',
          'archetype_details' => {
            '_type' => 'ARCHETYPED',
            'archetype_id' => { 'value' => 'openEHR-EHR-EVALUATION.invented_dt.v1' },
            'rm_version' => '1.0.4'
          },
          'data' => {
            '_type' => 'ITEM_TREE',
            'archetype_node_id' => 'at0001',
            'items' => [
              {
                'archetype_node_id' => 'at0002',
                '_type' => 'ELEMENT',
                'value' => { '_type' => 'DV_DATE_TIME', 'value' => value }
              }
            ]
          }
        }
      ]
    }
  end

  def committed(value, uid: "u-63-#{value}")
    canonical = canonical_with(value)
    builder = OpenehrRails::Rm::GraphBuilder.new(canonical)
    composition = OpenehrRails::Rm::Composition.create!(builder.composition_attributes.merge(uid: uid))
    builder.build!(composition)
    composition.reload
  end

  def canonical_value(composition)
    composition.to_canonical_hash.dig('content', 0, 'data', 'items', 0, 'value', 'value')
  end

  def rm_value(rm_composition)
    rm_composition.content.first.data.items.first.value.value
  end

  %w[2026-03-01 2026-03-01T10:00 2026-03-01T10:00:00+09:00].each do |original|
    it "serializes #{original} back to canonical JSON unchanged" do # bug: came back as a UTC instant
      expect(canonical_value(committed(original))).to eq(original)
    end

    it "rebuilds #{original} unchanged in to_rm" do # bug
      expect(rm_value(committed(original).to_rm)).to eq(original)
    end
  end

  it 'still stores the normalized instant in datetime_value' do # regression pin
    row = committed('2026-03-01T10:00:00+09:00').data_values.find_by(rm_type: 'DV_DATE_TIME')

    expect(row.datetime_value).to eq(Time.utc(2026, 3, 1, 1, 0, 0))
  end

  it 'hands AQL the normalized UTC value until the upstream offset fix' do # regression pin
    committed('2026-03-01T10:00:00+09:00')
    dataset = OpenehrRails::Aql::DatasetAdapter.build
    rm = dataset.each_ehr.flat_map(&:compositions).first

    expect(rm_value(rm)).to eq('2026-03-01T01:00:00Z')
  end

  it 'serializes a row written before #63 (no text_value) as the UTC instant' do # regression pin
    composition = committed('2026-03-01T10:00:00+09:00')
    composition.data_values.where(rm_type: 'DV_DATE_TIME').update_all(text_value: nil) # rubocop:disable Rails/SkipsModelValidations -- recreates a pre-#63 row

    expect(canonical_value(composition.reload)).to eq('2026-03-01T01:00:00Z')
    expect(rm_value(composition.to_rm)).to eq('2026-03-01T01:00:00Z')
  end

  it 'does not match a DV_DATE_TIME row by its original string in the path-value search' do # regression pin
    committed('2026-03-01')

    expect(OpenehrRails::Rm::DataValue.matching('2026-03-01').where(rm_type: 'DV_DATE_TIME')).to be_empty
  end
end

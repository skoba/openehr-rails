# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr_rails'

# #109 (R-20261127-31): a DV_DATE_TIME or DV_DATE of reduced precision
# (2026, 2026-11, 2026-11-27T09, ...) is stored. The committed string comes back
# unchanged (canonical JSON, to_rm); the normalized column used for ordering and
# SQL (datetime_value, date_value) holds the earliest instant (day) the value
# covers, a value without an offset read as UTC -- the instant the openehr gem
# orders it by (DvDateTime#magnitude / DvDate#magnitude, openehr 2.9.0 #120,
# #112). The normalized value is internal: it is not shown anywhere.
# rubocop:disable-next RSpec/DescribeClass -- the behavior spans GraphBuilder, the DV rows, CanonicalSerializer and RmObjectBuilder
describe 'partial DV_DATE_TIME and DV_DATE values (#109)' do
  def canonical_with(type, value, start_time: '2026-11-27T09:30:00Z')
    {
      '_type' => 'COMPOSITION',
      'archetype_node_id' => 'openEHR-EHR-COMPOSITION.invented_partial.v1',
      'archetype_details' => {
        '_type' => 'ARCHETYPED',
        'archetype_id' => { 'value' => 'openEHR-EHR-COMPOSITION.invented_partial.v1' },
        'template_id' => { 'value' => 'invented_partial' },
        'rm_version' => '1.0.4'
      },
      'context' => { '_type' => 'EVENT_CONTEXT', 'start_time' => { '_type' => 'DV_DATE_TIME', 'value' => start_time } },
      'content' => [
        {
          '_type' => 'EVALUATION',
          'archetype_node_id' => 'openEHR-EHR-EVALUATION.invented_partial.v1',
          'archetype_details' => {
            '_type' => 'ARCHETYPED',
            'archetype_id' => { 'value' => 'openEHR-EHR-EVALUATION.invented_partial.v1' },
            'rm_version' => '1.0.4'
          },
          'data' => {
            '_type' => 'ITEM_TREE',
            'archetype_node_id' => 'at0001',
            'items' => [
              { 'archetype_node_id' => 'at0002', '_type' => 'ELEMENT', 'value' => { '_type' => type, 'value' => value } }
            ]
          }
        }
      ]
    }
  end

  def committed(type, value, **options)
    builder = OpenehrRails::Rm::GraphBuilder.new(canonical_with(type, value, **options))
    composition = OpenehrRails::Rm::Composition.create!(
      builder.composition_attributes.merge(uid: "u-109-#{type}-#{value}-#{options.hash}")
    )
    builder.build!(composition)
    composition.reload
  end

  def canonical_value(composition)
    composition.to_canonical_hash.dig('content', 0, 'data', 'items', 0, 'value', 'value')
  end

  def rm_value(composition)
    composition.to_rm.content.first.data.items.first.value.value
  end

  def row(composition, type)
    composition.data_values.find_by(rm_type: type)
  end

  # The instant the openehr gem orders a value by: DvDateTime#magnitude counts
  # UTC seconds since 0001-01-01T00:00:00Z (a Float).
  def gem_instant(value)
    Time.utc(1, 1, 1) + OpenEHR::RM::DataTypes::Quantity::DateTime::DvDateTime.new(value: value).magnitude
  end

  # DvDate#magnitude counts days since 0001-01-01 (proleptic Gregorian).
  def gem_day(value)
    Date.new(1, 1, 1, Date::GREGORIAN) + OpenEHR::RM::DataTypes::Quantity::DateTime::DvDate.new(value: value).magnitude
  end

  describe 'DV_DATE_TIME' do
    %w[
      2026 2026-11 2026-11-27 2026-11-27T09 2026-11-27T09:30 2026-11-27T09:30:15
      2026-11-27T09:30:15.5+09:00 2026-11-27T09:30:15-03:30 2026-11-27T09:30:15Z
    ].each do |value|
      context value do
        it 'is stored and comes back unchanged in canonical JSON and to_rm' do # bug: 2026, 2026-11 raised ArgumentError
          composition = committed('DV_DATE_TIME', value)

          expect(canonical_value(composition)).to eq(value)
          expect(rm_value(composition)).to eq(value)
        end

        it 'normalizes to the instant the openehr gem orders it by' do # bug: read in Time.zone, hour dropped
          stored = Time.use_zone('Tokyo') { row(committed('DV_DATE_TIME', value), 'DV_DATE_TIME').datetime_value }

          expect(stored).to be_within(0.001).of(gem_instant(value))
        end
      end
    end

    it 'reads a value without an offset as UTC, whatever Time.zone is' do # bug
      stored = Time.use_zone('Tokyo') { row(committed('DV_DATE_TIME', '2026-11-27T09:30'), 'DV_DATE_TIME').datetime_value }

      expect(stored).to eq(Time.utc(2026, 11, 27, 9, 30))
    end

    it 'keeps microseconds exact' do # regression pin (the gem's Float magnitude drifts here)
      stored = row(committed('DV_DATE_TIME', '2026-11-27T09:30:15.123456+09:00'), 'DV_DATE_TIME').datetime_value

      expect(stored).to eq(Time.utc(2026, 11, 27, 0, 30, Rational(15_123_456, 1_000_000)))
    end

    it 'still stores a string the gem does not read, as before' do # regression pin
      composition = committed('DV_DATE_TIME', '20261127T093015Z')

      expect(row(composition, 'DV_DATE_TIME').datetime_value).to eq(Time.utc(2026, 11, 27, 9, 30, 15))
      expect(canonical_value(composition)).to eq('20261127T093015Z')
    end

    it 'stores a partial EVENT_CONTEXT start_time as its earliest instant' do # bug
      composition = committed('DV_DATE_TIME', '2026-11-27', start_time: '2026-11')

      expect(composition.context_start_time).to eq(Time.utc(2026, 11, 1))
    end
  end

  describe 'DV_DATE' do
    %w[2026 2026-11 2026-11-27].each do |value|
      context value do
        it 'is stored and comes back unchanged in canonical JSON and to_rm' do # bug: 2026, 2026-11 failed validation
          composition = committed('DV_DATE', value)

          expect(canonical_value(composition)).to eq(value)
          expect(rm_value(composition)).to eq(value)
        end

        it 'normalizes to the day the openehr gem orders it by' do # bug
          expect(row(committed('DV_DATE', value), 'DV_DATE').date_value).to eq(gem_day(value))
        end
      end
    end

    it 'is not found by a string search, as before' do # regression pin
      committed('DV_DATE', '2026-11')

      expect(OpenehrRails::Rm::DataValue.matching('2026-11').where(rm_type: 'DV_DATE')).to be_empty
    end
  end
end

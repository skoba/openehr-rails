# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# #110 (R-20261127-31): date and time leaves are served in FHIR's forms, by the
# rule Condition follows since #104, on both paths. The scaffold path hands the
# builder a typed column's Time or Date; the runtime path the committed string.
#   - dateTime: YYYY, YYYY-MM, YYYY-MM-DD as recorded; a time gets seconds
#     (zero-filled) and an offset (UTC when the record has none); a value to the
#     hour, which FHIR cannot write, is served to the day.
#   - DV_DATE: Observation.value[x] has no `date` in R5, so valueDateTime with
#     the date.
#   - DV_TIME: FHIR time is hh:mm:ss and SHALL NOT carry an offset.
describe OpenehrRails::Fhir::ResourceBuilder do
  def observation_archetype = 'openEHR-EHR-OBSERVATION.invented_dt.v1'

  def field(rm_type, node_id = 'at0004')
    { name: "f_#{node_id}", rm_type: rm_type, archetype_id: observation_archetype, node_id: node_id }
  end

  def observation(rm_type, value)
    entry = OpenehrRails::Fhir::ResourceRegistry::Entry.new(
      archetype_id: observation_archetype, rm_type: 'OBSERVATION', resource_type: 'Observation',
      fields: [field(rm_type)]
    )
    described_class.new(entry, values: { 'f_at0004' => value }, id: 'x').build
  end

  describe 'an Observation DV_DATE_TIME leaf' do
    it 'serves a typed column Time in ISO 8601 (scaffold path)' do # bug: Time#to_s
      expect(observation('DV_DATE_TIME', Time.utc(2026, 11, 20, 9, 30))[:valueDateTime]).to eq('2026-11-20T09:30:00Z')
      expect(observation('DV_DATE_TIME', Time.new(2026, 11, 20, 9, 30, 0, '+09:00'))[:valueDateTime])
        .to eq('2026-11-20T09:30:00+09:00')
    end

    # The first four were valid and served as recorded (regression pin); the
    # rest were passed on as recorded, not FHIR (bug).
    {
      '2026' => '2026', '2026-11' => '2026-11', '2026-11-27' => '2026-11-27',
      '2026-11-27T09:30:15+09:00' => '2026-11-27T09:30:15+09:00',
      '2026-11-27T09:30' => '2026-11-27T09:30:00Z',
      '2026-11-27T09:30:15' => '2026-11-27T09:30:15Z',
      '2026-11-27T09:30+09:00' => '2026-11-27T09:30:00+09:00',
      '2026-11-27T09' => '2026-11-27',
      '2026-11-27T09+09:00' => '2026-11-27'
    }.each do |recorded, served|
      it "serves #{recorded} as #{served} (runtime path)" do
        expect(observation('DV_DATE_TIME', recorded)[:valueDateTime]).to eq(served)
      end
    end

    it 'serves a component[] value by the same rule' do # bug
      entry = OpenehrRails::Fhir::ResourceRegistry::Entry.new(
        archetype_id: observation_archetype, rm_type: 'OBSERVATION', resource_type: 'Observation',
        fields: [field('DV_DATE_TIME', 'at0004'), field('DV_DATE_TIME', 'at0005')]
      )
      built = described_class.new(entry, values: { 'f_at0004' => Time.utc(2026, 11, 20, 9, 30),
                                                   'f_at0005' => '2026-11-27T09' }, id: 'x').build

      expect(built[:component].pluck(:valueDateTime))
        .to eq(['2026-11-20T09:30:00Z', '2026-11-27'])
    end
  end

  describe 'an Observation DV_DATE leaf' do
    it 'is served as valueDateTime with the date (no valueDate on Observation)' do # bug
      expect(observation('DV_DATE', Date.new(2026, 11, 27))).to include(valueDateTime: '2026-11-27')
      expect(observation('DV_DATE', '2026-11')).to include(valueDateTime: '2026-11')
      expect(observation('DV_DATE', '2026-11')).not_to have_key(:valueDate)
    end

    it 'is profiled as dateTime' do # bug: date, not allowed on Observation.value[x]
      expect(OpenehrRails::Fhir::TypeMap.datatype_for('DV_DATE')).to eq('dateTime')
    end
  end

  describe 'an Observation DV_TIME leaf' do
    it 'serves a typed column Time as hh:mm:ss (scaffold path)' do # bug: Time#to_s with a date
      expect(observation('DV_TIME', Time.utc(2000, 1, 1, 9, 30))[:valueTime]).to eq('09:30:00')
      expect(observation('DV_TIME', Time.utc(2000, 1, 1, 9, 30, 15.5r))[:valueTime]).to eq('09:30:15.5')
    end

    # 09:30:15 and 09:30:15.5 were served as is (regression pin); 09:30 lacked
    # seconds (bug). With an offset (bug; proposal in the PR): FHIR time SHALL
    # NOT carry an offset, so the clock reading as recorded is served and the
    # offset left out; converting to UTC would serve a reading the record does
    # not show (and can cross midnight).
    {
      '09:30:15' => '09:30:15', '09:30:15.5' => '09:30:15.5', '09:30' => '09:30:00',
      '09:30:15+09:00' => '09:30:15', '09:30:15Z' => '09:30:15'
    }.each do |recorded, served|
      it "serves #{recorded} as #{served} (runtime path)" do
        expect(observation('DV_TIME', recorded)[:valueTime]).to eq(served)
      end
    end

    # Proposal (PR): FHIR time has no form without minutes, and minutes are
    # not made up; the value is left out.
    it 'leaves out a value to the hour (runtime path)' do # bug: "09" was served
      expect(observation('DV_TIME', '09')).not_to have_key(:valueTime)
    end
  end

  describe 'a Condition date/time leaf' do
    def condition(recorded_date)
      archetype = 'openEHR-EHR-EVALUATION.problem_diagnosis.v1'
      entry = OpenehrRails::Fhir::ResourceRegistry::Entry.new(
        archetype_id: archetype, rm_type: 'EVALUATION', resource_type: 'Condition',
        fields: [{ name: 'at0003', rm_type: 'DV_DATE_TIME', archetype_id: archetype, node_id: 'at0003' }]
      )
      described_class.new(entry, values: { 'at0003' => recorded_date }, id: 'x').build
    end

    it 'serves a value to the hour to the day, as Observation does' do # bug: passed on as recorded
      expect(condition('2026-11-27T09')[:recordedDate]).to eq('2026-11-27')
    end

    it 'keeps the forms it already served' do # regression pin
      expect(condition('2026-11')[:recordedDate]).to eq('2026-11')
      expect(condition('2026-11-27T09:30')[:recordedDate]).to eq('2026-11-27T09:30:00Z')
    end
  end
end

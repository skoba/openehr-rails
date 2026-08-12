# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Rm::EhrSerializer do
  let(:ehr) do
    OpenehrRails::Rm::Ehr.create!(
      ehr_id: 'ehr-1', system_id: 'openehr-rails', subject_id: 'patient-42',
      subject_namespace: 'demo', is_queryable: true, is_modifiable: true
    )
  end

  describe '#call (canonical EHR JSON)' do
    it 'emits the canonical EHR shape with EHR_STATUS inlined' do
      hash = described_class.new(ehr).call

      expect(hash['_type']).to eq('EHR')
      expect(hash.dig('system_id', 'value')).to eq('openehr-rails')
      expect(hash.dig('ehr_id', 'value')).to eq('ehr-1')
      expect(hash['time_created']).to be_present
      expect(hash.dig('ehr_status', '_type')).to eq('EHR_STATUS')
      expect(hash.dig('ehr_status', 'subject', 'external_ref', 'id', 'value')).to eq('patient-42')
      expect(hash.dig('ehr_status', 'is_queryable')).to be true
      expect(hash.dig('ehr_status', 'is_modifiable')).to be true
    end
  end

  describe '#ehr_status (canonical EHR_STATUS JSON alone)' do
    it 'emits just the EHR_STATUS' do
      status = described_class.new(ehr).ehr_status

      expect(status['_type']).to eq('EHR_STATUS')
      expect(status.dig('subject', 'external_ref', 'id', 'value')).to eq('patient-42')
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Naming do
  it 'keeps simple template ids' do
    expect(described_class.model_name('bmi_calculation')).to eq('bmi_calculation')
  end

  it 'strips openEHR prefixes, RM types and versions' do
    expect(described_class.model_name('openEHR-EHR-COMPOSITION.vital_signs_encounter.v1'))
      .to eq('vital_signs_encounter')
  end

  it 'underscores separators' do
    expect(described_class.model_name('IDCR-MedicationStatement.v0'))
      .to eq('medicationstatement')
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# Issue #59 (openehr 2.5.0 adoption). Fixture: bmi_calculation_repeated_root.opt
# (kind: synthetic - bmi_calculation.opt with its body_mass_index root repeated).
describe OpenehrRails::Opt::Parser do
  let(:template) do
    OpenehrRails::Opt.parse(File.expand_path('../../templates/bmi_calculation_repeated_root.opt', __dir__))
  end
  let(:archetype_id) { 'openEHR-EHR-OBSERVATION.body_mass_index.v2' }

  # bug: red on openehr 2.4.3 (the bypass stacked one CodePhrase per occurrence: 2 each).
  it 'keeps one term binding per code when the same archetype is embedded twice' do
    bindings = template.component_terminologies.fetch(archetype_id).term_bindings
    counts = bindings.transform_values { |codes| codes.transform_values(&:size) }

    expect(counts).to eq('SNOMED-CT' => { 'at0004' => 1 }, 'LOINC' => { 'at0004' => 1 })
  end

  # bug: red on openehr 2.4.3 (each binding appeared twice in code_bindings).
  it 'gives each of the two fields one code_bindings entry per binding' do
    fields = OpenehrRails::Opt::FieldExtractor.new(template).fields.select { |field| field[:node_id] == 'at0004' }
    bmi_fields = fields.select { |field| field[:archetype_id] == archetype_id }

    expect(bmi_fields.size).to eq(2)
    expect(bmi_fields.pluck(:code_bindings)).to all(
      contain_exactly({ system_uri: 'SNOMED-CT', code: '[SNOMED-CT::60621009]' },
                      { system_uri: 'LOINC', code: '[LOINC::39156-5]' })
    )
  end
end

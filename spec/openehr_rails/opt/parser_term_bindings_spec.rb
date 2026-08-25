# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Opt::Parser do
  let(:opt_file) { File.expand_path('../../templates/bmi_calculation_without_uid.opt', __dir__) }
  let(:archetype_id) { 'openEHR-EHR-OBSERVATION.body_mass_index.v2' }

  def term_bindings(template)
    template.component_terminologies.fetch(archetype_id).term_bindings
  end

  def binding_values(bindings)
    bindings.transform_values do |codes|
      codes.transform_values do |phrases|
        phrases.map { |phrase| [phrase.terminology_id.value, phrase.code_string] }
      end
    end
  end

  it 'populates OPT term bindings in the ArchetypeOntology canonical shape' do
    # enhancement: pins the contract required before the openehr-ruby#31 bypass can be removed.
    bindings = term_bindings(OpenehrRails::Opt.parse(opt_file))

    snomed = bindings.fetch('SNOMED-CT').fetch('at0004').first
    expect(snomed).to be_a(OpenEHR::RM::DataTypes::Text::CodePhrase)
    expect(snomed.code_string).to eq('[SNOMED-CT::60621009]')
    expect(snomed.terminology_id.value).to eq('SNOMED-CT')

    loinc = bindings.fetch('LOINC').fetch('at0004').first
    expect(loinc.code_string).to eq('[LOINC::39156-5]')
  end

  it 'produces identical term bindings from a file path and raw XML content' do
    # enhancement: raw-content parsing must satisfy the same upstream #31 contract.
    raw_xml = File.read(opt_file)

    raw_bindings = term_bindings(OpenehrRails::Opt.parse(raw_xml))
    file_bindings = term_bindings(OpenehrRails::Opt.parse(opt_file))

    expect(raw_bindings).not_to be_nil
    expect(binding_values(raw_bindings)).to eq(binding_values(file_bindings))
  end
end

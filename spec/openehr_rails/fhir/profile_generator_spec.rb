# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Fhir::ProfileGenerator do
  let(:opt_file) do
    File.expand_path('../../generators/templates/bmi_calculation.opt', __dir__)
  end
  let(:template) { OpenehrRails::Opt.parse(opt_file) }
  let(:generator) { described_class.new(template) }

  describe '#profiles' do
    subject(:profiles) { generator.profiles }

    it 'builds one StructureDefinition per OBSERVATION entry' do
      expect(profiles.map { |p| p[:id] }).to contain_exactly(
        'openehr-observation-height-v2',
        'openehr-observation-body-weight-v2',
        'openehr-observation-body-mass-index-v2'
      )
    end

    describe 'the height profile' do
      subject(:profile) { profiles.find { |p| p[:id] == 'openehr-observation-height-v2' } }

      it 'is a FHIR R5 StructureDefinition' do
        expect(profile[:resourceType]).to eq('StructureDefinition')
        expect(profile[:fhirVersion]).to eq('5.0.0')
        expect(profile[:kind]).to eq('resource')
        expect(profile[:derivation]).to eq('constraint')
        expect(profile[:status]).to eq('draft')
      end

      it 'constrains the Observation base resource' do
        expect(profile[:type]).to eq('Observation')
        expect(profile[:baseDefinition])
          .to eq('http://hl7.org/fhir/StructureDefinition/Observation')
      end

      it 'carries a stable canonical url' do
        expect(profile[:url]).to eq('urn:openehr:openEHR-EHR-OBSERVATION.height.v2')
      end

      it 'fixes Observation.code to the archetype id' do
        code_element = profile.dig(:differential, :element)
                              .find { |e| e[:path] == 'Observation.code' }
        coding = code_element[:patternCodeableConcept][:coding].first
        expect(coding[:system]).to eq('http://openehr.org/ckm/archetypes')
        expect(coding[:code]).to eq('openEHR-EHR-OBSERVATION.height.v2')
      end

      it 'constrains value[x] to a Quantity with fixed unit' do
        value_element = profile.dig(:differential, :element)
                               .find { |e| e[:path] == 'Observation.value[x]' }
        expect(value_element[:type]).to eq([{ code: 'Quantity' }])
        expect(value_element[:patternQuantity]).to eq(
          unit: 'cm',
          system: 'http://unitsofmeasure.org',
          code: 'cm'
        )
      end
    end

    describe 'a multi-element entry (body_mass_index)' do
      subject(:profile) { profiles.find { |p| p[:id] == 'openehr-observation-body-mass-index-v2' } }

      it 'slices Observation.component per element' do
        component_slices = profile.dig(:differential, :element)
                                  .select { |e| e[:path] == 'Observation.component' }
        expect(component_slices).not_to be_empty
        expect(component_slices.first[:slicing][:discriminator].first[:path]).to eq('code')
      end
    end
  end

  describe '#to_json_files' do
    it 'returns id => pretty JSON string' do
      files = generator.to_json_files
      expect(files.keys).to include('openehr-observation-height-v2')
      parsed = JSON.parse(files['openehr-observation-height-v2'])
      expect(parsed['resourceType']).to eq('StructureDefinition')
    end
  end

  describe 'DV_CODED_TEXT bindings' do
    let(:problem_file) { File.expand_path('../../templates/problem_list.opt', __dir__) }
    let(:template) { OpenehrRails::Opt.parse(problem_file) }
    let(:elements) { generator.profiles.flat_map { |profile| profile.dig(:differential, :element) } }

    it 'emits a required value-set binding for C_CODE_REFERENCE constraints' do
      # bug repro for issue #30: the empty local code list previously suppressed binding entirely.
      expect(elements).to include(
        hash_including(
          binding: {
            strength: 'required',
            valueSet: 'terminology:http://id.who.int/icd/release/11/mms'
          }
        )
      )
    end

    it 'keeps a local code-list binding free of a valueSet' do
      # regression pin: a local code_list binding stays exactly strength-only.
      code_index = elements.index do |element|
        element.dig(:patternCodeableConcept, :coding, 0, :code)&.end_with?('#at0073')
      end
      value_element = elements.drop(code_index + 1).find { |element| element[:type] }

      expect(value_element[:binding]).to eq(strength: 'required')
    end
  end
end

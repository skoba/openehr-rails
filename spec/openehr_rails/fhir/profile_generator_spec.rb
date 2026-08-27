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
      # bug repro for issue #30: the empty local code list previously suppressed
      # binding entirely. at0002's code_list is empty and it still binds -- the
      # property #30 fixed. Since #33 this lands on Condition.code (was a
      # component slice) and the canonical is no longer emitted with OPT's
      # `terminology:` prefix.
      expect(elements).to include(
        hash_including(
          binding: {
            strength: 'required',
            valueSet: 'http://id.who.int/icd/release/11/mms'
          }
        )
      )
    end

    # Was: "keeps a local code-list binding free of a valueSet" -- a #30
    # regression pin on at0073's component slice getting a strength-only
    # binding. Since #33, at0073 maps to Condition.verificationStatus, whose
    # own required binding to condition-ver-status makes any archetype-local
    # binding invalid (plan section 8.2), so the emitted shape is "no binding"
    # rather than "strength-only". problem_list.opt is this repo's only fixture
    # with a local code_list, so ProfileGenerator#apply_value_constraints'
    # strength-only branch has no fixture exercising it any more -- recorded in
    # docs/reports/fsh-generator-log.md R10 rather than left implicit.
    it 'emits no binding at all for a local code list on a mapped leaf' do
      status = elements.find { |element| element[:path] == 'Condition.verificationStatus' }

      expect(status).not_to be_nil
      expect(status).not_to have_key(:binding)
    end
  end

  # skoba/openehr-rails#33. Same mapping as FshGenerator, from the same table
  # in TypeMap -- docs/design/multi-leaf-non-observation-plan.md section 8.
  # This is the JSON facade half of the fix: Condition.component disappears
  # from the generated StructureDefinition, which was the issue's own complaint.
  describe 'a multi-leaf EVALUATION entry (problem_list.opt)' do
    subject(:profile) do
      generator.profiles.find { |p| p[:id] == 'openehr-evaluation-problem-diagnosis-v1' }
    end

    let(:opt_file) do
      File.expand_path('../../templates/problem_list.opt', __dir__)
    end
    let(:paths) { profile[:differential][:element].map { |e| e[:path] } }

    it 'constrains the Condition base resource' do
      expect(profile[:type]).to eq('Condition')
      expect(profile[:baseDefinition])
        .to eq('http://hl7.org/fhir/StructureDefinition/Condition')
    end

    it 'produces no Condition.component element' do
      expect(paths.grep(/component/)).to be_empty
    end

    it 'anchors the archetype on Condition.category' do
      anchor = profile[:differential][:element].find { |e| e[:path] == 'Condition.category' }

      expect(anchor[:patternCodeableConcept][:coding].first).to include(
        system: 'http://openehr.org/ckm/archetypes',
        code: 'openEHR-EHR-EVALUATION.problem_diagnosis.v1'
      )
    end

    it 'binds Condition.code to the leaf value set rather than the archetype id' do
      code = profile[:differential][:element].find { |e| e[:path] == 'Condition.code' }

      expect(code[:binding]).to eq(
        strength: 'required',
        valueSet: 'http://id.who.int/icd/release/11/mms'
      )
    end

    it 'maps the date leaves onto onset[x], recordedDate and abatement[x]' do
      expect(paths).to include(
        'Condition.onset[x]', 'Condition.recordedDate', 'Condition.abatement[x]'
      )
      onset = profile[:differential][:element].find { |e| e[:path] == 'Condition.onset[x]' }
      expect(onset[:type]).to eq([{ code: 'dateTime' }])
    end

    # Plan section 8.2: verificationStatus already carries a required binding to
    # condition-ver-status, so at0073's local at-codes must not be bound here.
    it 'constrains verificationStatus without adding a binding' do
      status = profile[:differential][:element].find { |e| e[:path] == 'Condition.verificationStatus' }

      expect(status).not_to be_nil
      expect(status).not_to have_key(:binding)
    end
  end
end

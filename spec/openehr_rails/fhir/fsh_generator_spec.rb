# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Fhir::FshGenerator do
  let(:opt_file) do
    File.expand_path('../../generators/templates/bmi_calculation.opt', __dir__)
  end
  let(:template) { OpenehrRails::Opt.parse(opt_file) }
  let(:generator) { described_class.new(template) }

  describe '#to_fsh_files' do
    subject(:files) { generator.to_fsh_files }

    it 'builds one FSH profile per OBSERVATION entry' do
      expect(files.keys).to contain_exactly(
        'openehr-observation-height-v2',
        'openehr-observation-body-weight-v2',
        'openehr-observation-body-mass-index-v2'
      )
    end

    describe 'the height profile' do
      subject(:fsh) { files.fetch('openehr-observation-height-v2') }

      it 'emits metadata and slices codings by system' do
        expect(fsh).to include(
          "Alias: CKM = http://openehr.org/ckm/archetypes\n",
          "Alias: LOINC = http://loinc.org\n",
          "Profile: OpenehrObservationHeightV2\n",
          "Parent: Observation\n",
          "Id: openehr-observation-height-v2\n",
          "Title: \"openEHR Height (openEHR-EHR-OBSERVATION.height.v2)\"\n",
          "* code.coding ^slicing.discriminator.type = #value\n",
          "* code.coding ^slicing.discriminator.path = \"system\"\n",
          "* code.coding ^slicing.rules = #open\n",
          "* code.coding contains ckm 1..1 and loinc 0..1\n",
          "* code.coding[ckm] = CKM#openEHR-EHR-OBSERVATION.height.v2\n",
          "* code.coding[loinc] = LOINC#8302-2\n"
        )
      end

      it 'constrains value[x] to an optional Quantity with a fixed unit' do
        expect(fsh).to include(
          "* value[x] 0..1\n",
          "* value[x] only Quantity\n",
          '* value[x].unit = "cm"'
        )
      end
    end

    describe 'a multi-element entry (body_mass_index)' do
      subject(:fsh) { files.fetch('openehr-observation-body-mass-index-v2') }

      it 'slices component by code and constrains each slice value' do
        expect(fsh).to include(
          "* component ^slicing.discriminator.type = #pattern\n",
          "* component ^slicing.discriminator.path = \"code\"\n",
          "* component ^slicing.rules = #open\n",
          "* component contains bodymassindex 0..1\n",
          '* component[bodymassindex].code.coding ' \
          "^slicing.discriminator.type = #value\n",
          '* component[bodymassindex].code.coding ' \
          "^slicing.discriminator.path = \"system\"\n",
          "* component[bodymassindex].code.coding ^slicing.rules = #open\n",
          '* component[bodymassindex].code.coding contains ' \
          "ckm 1..1 and snomedct 0..1 and loinc 0..1\n",
          '* component[bodymassindex].code.coding[ckm] = ' \
          "CKM#openEHR-EHR-OBSERVATION.body_mass_index.v2#at0004\n",
          "* component[bodymassindex].value[x] only Quantity\n",
          '* component[bodymassindex].value[x].unit = "kg/m2"'
        )
      end

      it 'writes each ontology code binding into its coding slice' do
        expect(fsh).to include(
          "Alias: CKM = http://openehr.org/ckm/archetypes\n",
          "Alias: SNOMEDCT = http://snomed.info/sct\n",
          "Alias: LOINC = http://loinc.org\n",
          '* component[bodymassindex].code.coding[snomedct] = ' \
          "SNOMEDCT#60621009\n",
          '* component[bodymassindex].code.coding[loinc] = ' \
          "LOINC#39156-5\n"
        )
      end
    end
  end

  describe 'value-set bindings' do
    let(:opt_file) { File.expand_path('../../templates/problem_list.opt', __dir__) }

    it 'emits a required binding for a C_CODE_REFERENCE constraint' do
      fsh = generator.to_fsh_files.fetch('openehr-evaluation-problem-diagnosis-v1')

      expect(fsh).to include(
        '* component[problemdiagnosisat0002].value[x] from ' \
        'http://id.who.int/icd/release/11/mms (required)'
      )
    end
  end
end

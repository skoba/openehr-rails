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

      # Since #33 this leaf lands on Condition.code rather than a component
      # slice; the #30 property under test -- an empty local code_list no
      # longer suppresses the binding -- is unchanged.
      expect(fsh).to include(
        '* code from http://id.who.int/icd/release/11/mms (required)'
      )
    end
  end

  # skoba/openehr-rails#33. The 5-leaf EVALUATION entry maps onto real
  # Condition elements instead of the nonexistent Condition.component; the
  # mapping and its per-element rationale are
  # docs/design/multi-leaf-non-observation-plan.md section 8.
  #
  # Golden provenance: spec/fixtures/fsh/openehr-evaluation-problem-diagnosis-v1.fsh
  # is generated output, not a hand-authored artifact -- it is this generator's
  # expected emission for spec/templates/problem_list.opt, and every rule in it
  # was compiled against hl7.fhir.r5.core#5.0.0 with sushi 3.16.0 (0 Errors)
  # before the implementation existed. It therefore carries no leading comment:
  # the file must byte-match what the generator produces.
  describe 'a multi-leaf EVALUATION entry (problem_list.opt)' do
    subject(:fsh) do
      generator.to_fsh_files.fetch('openehr-evaluation-problem-diagnosis-v1')
    end

    let(:opt_file) do
      File.expand_path('../../templates/problem_list.opt', __dir__)
    end
    let(:golden) do
      File.read(File.expand_path('../../fixtures/fsh/openehr-evaluation-problem-diagnosis-v1.fsh', __dir__))
    end

    it 'matches the golden FSH exactly' do
      expect(fsh).to eq(golden)
    end

    it 'never constrains component, which Condition does not have' do
      expect(fsh).not_to include('component')
    end

    # #33 ruling correction 1 (plan section 9.1): the archetype coding is a
    # slice of category, not a fixed coding on the whole element. category is
    # 0..* and an instance may carry other categories beside the archetype
    # coding; fixing coding.system/code on the element itself constrained every
    # repetition. Resolution shape (b) enhancement: red on the pre-correction
    # output, which emitted `* category.coding.code = ...`.
    it 'anchors the archetype in its own category slice, leaving code for the diagnosis itself' do
      expect(fsh).to include(
        "* category ^slicing.discriminator.type = #pattern\n",
        "* category ^slicing.discriminator.path = \"$this\"\n",
        "* category ^slicing.rules = #open\n",
        "* category contains ckm 1..1\n",
        '* category[ckm] = http://openehr.org/ckm/archetypes' \
        "#openEHR-EHR-EVALUATION.problem_diagnosis.v1\n",
        "* code from http://id.who.int/icd/release/11/mms (required)\n"
      )
      expect(fsh).not_to include('* category.coding')
    end

    it 'maps the three date leaves onto their Condition counterparts' do
      expect(fsh).to include(
        "* onsetDateTime only dateTime\n",
        "* recordedDate only dateTime\n",
        "* abatementDateTime only dateTime\n"
      )
    end

    # #33 ruling correction 2 (plan section 9.2): at0003 -> recordedDate is an
    # approximation (plan section 8.1), and the profile itself says so via
    # ElementDefinition.comment rather than leaving it in a design doc only.
    it 'records the at0003 -> recordedDate approximation as a ^comment' do
      expect(fsh).to match(/^\* recordedDate \^comment = "Approximation: openEHR at0003 .+"$/)
    end

    # at0073's local at-codes cannot be bound: Condition.verificationStatus has
    # a required binding to condition-ver-status, so translating them is a
    # ConceptMap concern (plan section 8.2).
    it 'constrains verificationStatus without binding the local code list' do
      expect(fsh).to include("* verificationStatus only CodeableConcept\n")
      expect(fsh).not_to include('verificationStatus from')
    end
  end

  # #33 ruling corrections 3 and 4 (plan section 9.3): an entry with more than
  # one leaf, a base resource without `component`, and no row in
  # TypeMap::ENTRY_ELEMENT_MAPS is skipped and reported through #skipped as an
  # UnsupportedProfileError -- neither silently emitting constraints on a path
  # the resource does not have (the original #33 defect) nor aborting the
  # whole batch. Resolution shape (b) enhancement: red on the pre-correction
  # code, which took the component path for such an entry.
  #
  # Synthetic entry, not a fixture file: no real multi-leaf INSTRUCTION OPT
  # exists in this repo (#35 is blocked on exactly that), so FieldExtractor is
  # stubbed to return problem_list.opt's real entry plus one invented
  # INSTRUCTION entry whose archetype id cannot be mistaken for a real one.
  describe 'an unmapped multi-leaf non-Observation entry' do
    subject(:files) { generator.to_fsh_files }

    let(:opt_file) { File.expand_path('../../templates/problem_list.opt', __dir__) }
    let(:real_entries) { OpenehrRails::Opt::FieldExtractor.new(template).entries }
    let(:synthetic_id) { 'openEHR-EHR-INSTRUCTION.synthetic_unmapped_test.v1' }
    let(:synthetic_entry) do
      real = real_entries.first
      real.merge(
        archetype_id: synthetic_id,
        rm_type: 'INSTRUCTION',
        concept: 'synthetic_unmapped_test',
        fields: real[:fields].first(2).map { |field| field.merge(archetype_id: synthetic_id) }
      )
    end

    before do
      extractor = instance_double(OpenehrRails::Opt::FieldExtractor, entries: [synthetic_entry, *real_entries])
      allow(OpenehrRails::Opt::FieldExtractor).to receive(:new).with(template).and_return(extractor)
    end

    it 'skips the entry and still emits the mapped one' do
      expect(files.keys).to eq(['openehr-evaluation-problem-diagnosis-v1'])
    end

    it 'reports the skip as an UnsupportedProfileError naming the archetype and resource' do
      files
      error = generator.skipped.first

      expect(generator.skipped.size).to eq(1)
      expect(error).to be_a(OpenehrRails::Fhir::UnsupportedProfileError)
      expect(error.archetype_id).to eq(synthetic_id)
      expect(error.resource_type).to eq('ServiceRequest')
      expect(error.message).to include(synthetic_id, 'ServiceRequest', 'component')
    end
  end

  describe '#skipped' do
    it 'is empty for an all-Observation template' do
      generator.to_fsh_files

      expect(generator.skipped).to be_empty
    end
  end
end

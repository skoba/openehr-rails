# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require 'tmpdir'
require_relative '../storable_spec_model'

# #101 (R-20261127-11 plan, R-20261127-15 answers): the FHIR facade reads
# records of templates registered at runtime -- compositions in the RM graph
# with no owning scaffolded model -- through the same endpoints as the
# scaffold path.
#   - the host hands over only its templates (OpenehrRails::Fhir.template_source);
#     records and values come from the RM graph (answer 1);
#   - runtime records are those without an owner; a template that has a
#     scaffolded model is served by the scaffold path only (answer 2);
#   - one template per template_id; a repeated template_id is a configuration
#     error naming it (answer 3);
#   - stages 1-3 serve Observation entries only (plan 3.3).
describe OpenehrRails::Fhir::ObservationQuery do
  let(:bmi_opt) { File.read(File.expand_path('../../generators/templates/bmi_calculation.opt', __dir__)) }
  let(:problem_list_opt) { File.read(File.expand_path('../../templates/problem_list.opt', __dir__)) }
  let(:height_code) { 'openEHR-EHR-OBSERVATION.height.v2' }
  let(:uuid) { '8849182c-82ad-4088-a07a-48ead4180515' }
  let(:hex) { uuid.delete('-') }

  around do |example|
    saved_models = OpenehrRails::Fhir::ResourceRegistry.model_names.dup
    OpenehrRails::Fhir::ResourceRegistry.reset!
    OpenehrRails::Fhir.template_source = -> { [{ template_id: 'bmi_calculation', opt: bmi_opt }] }
    example.run
  ensure
    OpenehrRails::Fhir.template_source = nil
    OpenehrRails::Fhir::ResourceRegistry.reset!
    saved_models.each { |name| OpenehrRails::Fhir::ResourceRegistry.register_model(name) }
  end

  # A runtime record: the canonical COMPOSITION a form would commit, with no owner.
  def commit_runtime(uid:, ehr_id: 'ehr-1', height: 170.0, body_weight: nil, at: Time.utc(2026, 11, 20, 9, 30))
    canonical = BmiCalculation.new(height: height, body_weight: body_weight).to_rm_composition
    ehr = OpenehrRails::Rm::Ehr.find_or_create_by!(ehr_id: ehr_id)
    OpenehrRails::Rm::CompositionCommitter.commit(canonical, uid: uid, ehr: ehr, context_start_time: at)
  end

  def search(code: nil, subject: nil)
    OpenehrRails::Fhir::ObservationQuery.new(code: code, subject: subject).search
  end

  describe 'search' do
    it 'lists a runtime record under its archetype code' do # enhancement
      commit_runtime(uid: uuid)

      observations = search(code: height_code)

      expect(observations.size).to eq(1)
      expect(observations.first).to include(
        resourceType: 'Observation',
        id: "c#{hex}-0",
        subject: { reference: 'Patient/ehr-1' },
        effectiveDateTime: '2026-11-20T09:30:00Z',
        valueQuantity: { value: 170.0, unit: 'cm', system: 'http://unitsofmeasure.org', code: 'cm' }
      )
    end

    it 'lists every entry that has data when no code is given' do # enhancement
      commit_runtime(uid: uuid, body_weight: 65.0)

      expect(search.pluck(:id)).to contain_exactly("c#{hex}-0", "c#{hex}-1")
    end

    it 'narrows to one EHR with subject=Patient/<ehr_id>' do # enhancement
      commit_runtime(uid: uuid, ehr_id: 'ehr-1')
      commit_runtime(uid: 'b2f0a6a4-1f0c-4c55-9a43-7a2f2f0c9d11', ehr_id: 'ehr-2')

      expect(search(code: height_code, subject: 'Patient/ehr-2').pluck(:subject))
        .to eq([{ reference: 'Patient/ehr-2' }])
    end

    it 'reads the latest version and leaves out a deleted record' do # enhancement
      commit_runtime(uid: uuid, height: 170.0)
      commit_runtime(uid: uuid, height: 171.0)
      deleted = 'b2f0a6a4-1f0c-4c55-9a43-7a2f2f0c9d11'
      commit_runtime(uid: deleted)
      OpenehrRails::Rm::CompositionCommitter.delete(uid: deleted)

      expect(search(code: height_code).map { |o| o.dig(:valueQuantity, :value) }).to eq([171.0])
    end

    it 'does not serve a record whose uid is not a UUID (no valid FHIR id for it)' do # enhancement
      commit_runtime(uid: 'client-chosen-uid')

      expect(search(code: height_code)).to eq([])
    end

    it 'leaves out records owned by a scaffolded model' do # regression pin
      BmiCalculation.create!(height: 160.0, ehr_id: 'ehr-9')

      expect(search(code: height_code)).to eq([])
    end

    it 'serves a template that has a scaffolded model by the scaffold path only, never twice' do # regression pin
      OpenehrRails::Fhir::ResourceRegistry.register_model(BmiCalculation)
      record = BmiCalculation.create!(height: 160.0, ehr_id: 'ehr-9')
      commit_runtime(uid: uuid)

      expect(search(code: height_code).pluck(:id)).to eq(["#{record.id}-openehr-observation-height-v2"])
    end
  end

  describe 'read by id' do
    it 'finds one runtime record by c<uuid hex>-<entry index>' do # enhancement
      commit_runtime(uid: uuid, body_weight: 65.0)

      observation = described_class.find("c#{hex}-1")

      expect(observation[:code][:coding].first[:code]).to eq('openEHR-EHR-OBSERVATION.body_weight.v2')
    end

    it 'finds nothing for a deleted record or an unknown id' do # enhancement
      commit_runtime(uid: uuid)
      OpenehrRails::Rm::CompositionCommitter.delete(uid: uuid)

      expect(described_class.find("c#{hex}-0")).to be_nil
      expect(described_class.find('c0000-0')).to be_nil
    end

    it 'still reads a scaffolded record by <record id>-<slug>' do # regression pin
      OpenehrRails::Fhir::ResourceRegistry.register_model(BmiCalculation)
      record = BmiCalculation.create!(height: 160.0, ehr_id: 'ehr-9')

      observation = described_class.find("#{record.id}-openehr-observation-height-v2")

      expect(observation[:valueQuantity][:value]).to eq(160.0)
    end
  end

  describe 'entries' do
    it 'lists runtime entries in the CapabilityStatement' do # enhancement
      profiles = OpenehrRails::Fhir::CapabilityStatement.build[:rest].first[:resource]
                                                        .flat_map { |r| r[:supportedProfile] }

      expect(profiles).to include("urn:openehr:#{height_code}")
    end

    it 'lists an archetype once in the CapabilityStatement when two templates use it' do # enhancement
      described_template = { template_id: 'bmi_calculation', opt: bmi_opt }
      OpenehrRails::Fhir.template_source = -> { [described_template, described_template.merge(template_id: 'bmi_copy')] }

      profiles = OpenehrRails::Fhir::CapabilityStatement.build[:rest].first[:resource]
                                                        .flat_map { |r| r[:supportedProfile] }

      expect(profiles.count("urn:openehr:#{height_code}")).to eq(1)
    end

    it 'serves Observation entries only (no Condition until the EVALUATION fix)' do # regression pin
      OpenehrRails::Fhir.template_source = -> { [{ template_id: 'ProblemList', opt: problem_list_opt }] }

      expect(OpenehrRails::Fhir::ResourceRegistry.entries).to eq([])
    end

    it 'stops on a template_id returned twice, naming it' do # enhancement
      OpenehrRails::Fhir.template_source = lambda do
        [{ template_id: 'bmi_calculation', opt: bmi_opt }, { template_id: 'bmi_calculation', opt: bmi_opt }]
      end

      expect { OpenehrRails::Fhir::ResourceRegistry.entries }
        .to raise_error(OpenehrRails::Fhir::TemplateSourceError, /bmi_calculation/)
    end

    it 'refuses to create through a runtime entry (no model to create into)' do # enhancement
      expect { described_class.creatable_entry(height_code) }
        .to raise_error(OpenehrRails::Fhir::Deserializer::UnmappedResource, /runtime/)
    end
  end

  describe 'profiles' do
    it 'generates the StructureDefinition of a template from the source' do # enhancement
      id = OpenehrRails::Fhir::ProfileGenerator.new(OpenehrRails::Opt.parse(bmi_opt)).profiles.first[:id]

      Dir.mktmpdir do |root|
        expect(OpenehrRails::Fhir::ProfileRepository.find(id, root: root)).to include(id: id)
      end
    end

    it 'finds it also when the host has profile files for other templates' do # enhancement
      id = OpenehrRails::Fhir::ProfileGenerator.new(OpenehrRails::Opt.parse(bmi_opt)).profiles.first[:id]

      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, 'app/fhir/profiles'))
        File.write(File.join(root, 'app/fhir/profiles/other.json'), JSON.generate('id' => 'other'))

        expect(OpenehrRails::Fhir::ProfileRepository.find(id, root: root)).to include(id: id)
      end
    end
  end
end

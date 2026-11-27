# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../storable_spec_model'

# #104 (R-20261127-15 answer 4, plan docs/design/104-condition-resources-plan.md):
# the FHIR facade served every entry as an Observation. An entry is now served
# as the resource its profile describes -- Observation entries as before, an
# entry with a TypeMap::ENTRY_ELEMENT_MAPS row as that resource (today
# problem_diagnosis -> Condition, mapping table multi-leaf-non-observation-plan
# section 8.1), any other entry not at all -- on both the scaffold path and the
# runtime path (#101).
describe OpenehrRails::Fhir::ResourceQuery do
  def problem_list_path = File.expand_path('../../templates/problem_list.opt', __dir__)
  def problem_list_opt = File.read(problem_list_path)
  def archetype = 'openEHR-EHR-EVALUATION.problem_diagnosis.v1'
  def uuid = '8849182c-82ad-4088-a07a-48ead4180515'

  let(:field_map) do
    OpenehrRails::Opt::FieldExtractor.new(OpenehrRails::Opt.parse(problem_list_path)).fields
                                     .index_by { |field| field[:name] }.freeze
  end
  let(:values) do
    { 'problem_diagnosis_at0002' => 'CA40.0', 'problem_diagnosis_at0077' => '2026-11-01T08:00:00+09:00',
      'problem_diagnosis_at0003' => '2026-11-02', 'problem_diagnosis_at0073' => 'at0076',
      'problem_diagnosis_at0070' => '2026-11-03T10:00:00+09:00' }
  end

  around do |example|
    saved_models = OpenehrRails::Fhir::ResourceRegistry.model_names.dup
    OpenehrRails::Fhir::ResourceRegistry.reset!
    OpenehrRails::Fhir.template_source = -> { [] }
    example.run
  ensure
    OpenehrRails::Fhir.template_source = nil
    OpenehrRails::Fhir::ResourceRegistry.reset!
    saved_models.each { |name| OpenehrRails::Fhir::ResourceRegistry.register_model(name) }
  end

  # A scaffold-style problem list model (string columns, as storable_models.rb).
  def problem_list_model
    fields = field_map
    ActiveRecord::Base.connection.create_table(:problem_list_records, force: true, temporary: true) do |t|
      fields.each_key { |name| t.string name }
      t.json :rm_composition
      t.string :template_id
      t.string :uid
      t.string :ehr_id
      t.datetime :composed_at
    end
    model = Class.new(ActiveRecord::Base) do # rubocop:disable Rails/ApplicationRecord
      self.table_name = 'problem_list_records'
      def self.name = 'ProblemListRecord'
    end
    stub_const('ProblemListRecord', model)
    model.const_set(:TEMPLATE_ID, 'problem_list_records')
    model.const_set(:ROOT_ARCHETYPE_ID, 'openEHR-EHR-COMPOSITION.problem_list.v2')
    model.const_set(:FIELD_MAP, fields)
    model.include(OpenehrRails::Storable)
    model
  end

  # A runtime record of the same template: no owner, diagnosis text in the record.
  def commit_runtime(ehr_id: 'ehr-1')
    OpenehrRails::Fhir.template_source = -> { [{ template_id: 'ProblemList', opt: problem_list_opt }] }
    canonical = problem_list_model.new(values).to_rm_composition
    canonical['archetype_details']['template_id']['value'] = 'ProblemList'
    OpenehrRails::Storable.value_node(canonical, field_map['problem_diagnosis_at0002'])['value'] = '肺炎'
    ehr = OpenehrRails::Rm::Ehr.find_or_create_by!(ehr_id: ehr_id)
    OpenehrRails::Rm::CompositionCommitter.commit(canonical, uid: uuid, ehr: ehr)
    OpenehrRails::Fhir::ResourceRegistry.reset!
  end

  def search(resource_type, archetype_id: nil, subject: nil)
    described_class.new(resource_type: resource_type, archetype_id: archetype_id, subject: subject).search
  end

  describe 'a scaffolded problem list record' do
    let!(:record) { problem_list_model.create!(values.merge('ehr_id' => 'ehr-9')) }

    it 'is not served as an Observation' do # bug
      expect(search('Observation')).to eq([])
    end

    it 'is served as a Condition laid out by the mapping table' do # bug
      condition = search('Condition', archetype_id: archetype).sole

      expect(condition).to eq(
        resourceType: 'Condition',
        id: "#{record.id}-openehr-evaluation-problem-diagnosis-v1",
        category: [{ coding: [{ system: 'http://openehr.org/ckm/archetypes', code: archetype }] }],
        subject: { reference: 'Patient/ehr-9' },
        # system: the field's terminology_id, else 'local' -- the rule coded
        # Observation values already follow (this leaf has a value set, no terminology_id).
        code: { coding: [{ system: 'local', code: 'CA40.0', display: 'CA40.0' }] },
        onsetDateTime: '2026-11-01T08:00:00+09:00',
        recordedDate: '2026-11-02',
        verificationStatus: { coding: [{ system: 'local', code: 'at0076',
                                         display: field_map['problem_diagnosis_at0073'][:code_labels]['at0076'] }] }
      )
    end

    it 'is read by id as a Condition only' do # enhancement
      id = "#{record.id}-openehr-evaluation-problem-diagnosis-v1"

      expect(described_class.find(id, resource_type: 'Condition')).to include(resourceType: 'Condition', id: id)
      expect(described_class.find(id, resource_type: 'Observation')).to be_nil
    end

    it 'narrows by subject' do # enhancement
      expect(search('Condition', subject: 'Patient/ehr-other')).to eq([])
    end

    it 'cannot be created through the Observation endpoint' do # bug
      expect { described_class.creatable_entry(archetype) }
        .to raise_error(OpenehrRails::Fhir::Deserializer::UnmappedResource, /Condition/)
    end
  end

  describe 'a runtime problem list record' do
    it 'is served as a Condition, with the diagnosis text from the record as display' do # enhancement
      commit_runtime

      condition = search('Condition', archetype_id: archetype).sole

      expect(condition[:id]).to eq("c#{uuid.delete('-')}-0")
      expect(condition[:code][:coding].first).to include(code: 'CA40.0', display: '肺炎')
      expect(search('Observation')).to eq([])
    end
  end

  describe 'the CapabilityStatement' do
    it 'lists Condition as read and search by category and subject, without create' do # enhancement
      problem_list_model

      condition = OpenehrRails::Fhir::CapabilityStatement.build[:rest].first[:resource]
                                                         .find { |r| r[:type] == 'Condition' }

      expect(condition[:interaction]).to eq([{ code: 'read' }, { code: 'search-type' }])
      expect(condition[:searchParam].pluck(:name)).to eq(%w[category subject])
      expect(condition[:supportedProfile]).to eq(["urn:openehr:#{archetype}"])
    end
  end

  describe 'Observation entries' do # regression pin
    it 'are served as before' do
      OpenehrRails::Fhir::ResourceRegistry.register_model(BmiCalculation)
      record = BmiCalculation.create!(height: 170.0, ehr_id: 'ehr-1')

      expect(search('Observation', archetype_id: 'openEHR-EHR-OBSERVATION.height.v2'))
        .to eq(OpenehrRails::Fhir::Serializer.new(record).observations.first(1))
    end
  end
end

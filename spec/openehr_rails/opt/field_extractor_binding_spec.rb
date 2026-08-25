# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require 'ostruct'

# rubocop:disable Style/OpenStructUse
describe OpenehrRails::Opt::FieldExtractor do
  def field_for(fields, archetype_id, node_id)
    fields.find { |field| field[:archetype_id] == archetype_id && field[:node_id] == node_id }
  end

  describe 'terminology bindings from parsed OPT fixtures' do
    let(:bmi_file) { File.expand_path('../../templates/bmi_calculation_without_uid.opt', __dir__) }
    let(:bmi_fields) { described_class.new(OpenehrRails::Opt.parse(bmi_file)).fields }

    it 'adds both binding keys to every field' do
      # enhancement: the two new binding keys are an always-present field-hash contract.
      expect(bmi_fields).to all(satisfy do |field|
        field.key?(:value_set_uri) && field.key?(:code_bindings)
      end)
    end

    it 'extracts code bindings for non-coded quantity fields' do
      # enhancement: ontology code bindings apply independently of the RM value type.
      height = field_for(bmi_fields, 'openEHR-EHR-OBSERVATION.height.v2', 'at0004')

      expect(height[:rm_type]).to eq('DV_QUANTITY')
      expect(height[:code_bindings]).to eq(
        [{ system_uri: 'LOINC', code: '[LOINC::8302-2]' }]
      )
    end

    it 'preserves multi-terminology code binding document order' do
      # enhancement: consumers receive bindings in their OPT document order.
      bmi = field_for(bmi_fields, 'openEHR-EHR-OBSERVATION.body_mass_index.v2', 'at0004')

      expect(bmi[:code_bindings]).to eq(
        [
          { system_uri: 'SNOMED-CT', code: '[SNOMED-CT::60621009]' },
          { system_uri: 'LOINC', code: '[LOINC::39156-5]' }
        ]
      )
    end
  end

  describe 'coded-text constraints' do
    let(:problem_file) { File.expand_path('../../templates/problem_list.opt', __dir__) }
    let(:fields) { described_class.new(OpenehrRails::Opt.parse(problem_file)).fields }
    let(:archetype_id) { 'openEHR-EHR-EVALUATION.problem_diagnosis.v1' }

    it 'selects and extracts a C_CODE_REFERENCE alternative' do
      # enhancement: prefer the external value-set alternative over a leading DV_TEXT alternative.
      problem = field_for(fields, archetype_id, 'at0002')

      expect(problem[:value_set_uri]).to eq('terminology:http://id.who.int/icd/release/11/mms')
      expect(problem[:rm_type]).to eq('DV_CODED_TEXT')
      expect(problem[:code_list]).to eq([])
    end

    it 'retains local code-list constraints' do
      # regression pin: local CODE_PHRASE enumerations keep their existing representation.
      diagnostic_status = field_for(fields, archetype_id, 'at0073')

      expect(diagnostic_status[:value_set_uri]).to be_nil
      expect(diagnostic_status[:code_list]).not_to be_empty
    end
  end

  describe 'a hand-built template without terminology objects' do
    def attribute(name, children)
      OpenStruct.new(rm_attribute_name: name, children: children)
    end

    it 'returns nil-safe binding defaults' do
      element = OpenStruct.new(
        rm_type_name: 'ELEMENT',
        node_id: 'at0004',
        occurrences: OpenStruct.new(lower: 1),
        attributes: [attribute('value', [OpenStruct.new(rm_type_name: 'DV_TEXT')])]
      )
      observation = OpenStruct.new(
        rm_type_name: 'OBSERVATION',
        node_id: 'at0000',
        archetype_id: OpenStruct.new(value: 'openEHR-EHR-OBSERVATION.example.v1'),
        occurrences: OpenStruct.new(lower: 1),
        attributes: [attribute('data', [element])]
      )
      template = OpenStruct.new(
        definition: OpenStruct.new(attributes: [attribute('content', [observation])]),
        component_terminologies: {}
      )

      # enhancement: additive binding keys remain safe for lightweight template doubles.
      expect(described_class.new(template).fields.first)
        .to include(value_set_uri: nil, code_bindings: [])
    end
  end
end
# rubocop:enable Style/OpenStructUse

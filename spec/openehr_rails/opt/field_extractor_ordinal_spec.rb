require 'spec_helper'
require 'openehr_rails'
require 'ostruct'

# openehr ~> 2.0 added C_DV_ORDINAL/C_DV_SCALE constraint parsing (vitals/exam
# templates use these heavily, e.g. pain scales, consciousness levels). These
# specs pin FieldExtractor's handling of the resulting constraint shape using
# lightweight doubles, so they don't depend on a particular openehr gem build.
describe OpenehrRails::Opt::FieldExtractor do
  def attribute(name, children)
    OpenStruct.new(rm_attribute_name: name, children: children)
  end

  def ordinal_item(value, code)
    symbol = OpenStruct.new(defining_code: OpenStruct.new(code_string: code))
    OpenStruct.new(value: value, symbol: symbol)
  end

  let(:archetype_id) { 'openEHR-EHR-OBSERVATION.exam.v1' }

  let(:template) do
    OpenStruct.new(
      definition: OpenStruct.new(attributes: [attribute('content', [observation])]),
      component_terminologies: {}
    )
  end

  let(:extractor) { described_class.new(template) }

  describe 'an ELEMENT constrained to C_DV_ORDINAL' do
    let(:constraint) do
      OpenStruct.new(rm_type_name: 'DV_ORDINAL', list: [ordinal_item(0, 'at0034'), ordinal_item(1, 'at0035')])
    end

    let(:element) do
      OpenStruct.new(
        rm_type_name: 'ELEMENT',
        node_id: 'at0004',
        occurrences: OpenStruct.new(lower: 1),
        attributes: [attribute('value', [constraint])]
      )
    end

    let(:observation) do
      OpenStruct.new(
        rm_type_name: 'OBSERVATION',
        node_id: 'at0000',
        archetype_id: OpenStruct.new(value: archetype_id),
        occurrences: OpenStruct.new(lower: 1),
        attributes: [attribute('data', [element])]
      )
    end

    it 'maps to an integer column' do
      field = extractor.fields.first
      expect(field[:rm_type]).to eq('DV_ORDINAL')
      expect(field[:column_type]).to eq(:integer)
    end

    it 'extracts the ordinal symbols as a code list' do
      field = extractor.fields.first
      expect(field[:code_list]).to eq(%w[at0034 at0035])
      expect(field[:code_labels]).to eq('at0034' => 'at0034', 'at0035' => 'at0035')
    end

    it 'maps each ordinal value to its symbol code' do
      field = extractor.fields.first
      expect(field[:value_code_map]).to eq(0 => 'at0034', 1 => 'at0035')
    end
  end

  describe 'an ELEMENT constrained to C_DV_SCALE' do
    let(:constraint) do
      OpenStruct.new(rm_type_name: 'DV_SCALE', list: [ordinal_item(1.0, 'at0010'), ordinal_item(2.0, 'at0011')])
    end

    let(:element) do
      OpenStruct.new(
        rm_type_name: 'ELEMENT',
        node_id: 'at0004',
        occurrences: OpenStruct.new(lower: 1),
        attributes: [attribute('value', [constraint])]
      )
    end

    let(:observation) do
      OpenStruct.new(
        rm_type_name: 'OBSERVATION',
        node_id: 'at0000',
        archetype_id: OpenStruct.new(value: archetype_id),
        occurrences: OpenStruct.new(lower: 1),
        attributes: [attribute('data', [element])]
      )
    end

    it 'maps to a float column' do
      field = extractor.fields.first
      expect(field[:rm_type]).to eq('DV_SCALE')
      expect(field[:column_type]).to eq(:float)
    end

    it 'extracts the scale symbols as a code list' do
      field = extractor.fields.first
      expect(field[:code_list]).to eq(%w[at0010 at0011])
    end
  end
end

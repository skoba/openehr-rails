require 'spec_helper'
require 'openehr_rails'
require 'ostruct'

# Archetype concepts can contain characters that are illegal in Ruby
# identifiers / SQL column names, most commonly a hyphen (e.g. the
# `openEHR-EHR-OBSERVATION.heart_rate-pulse.v1` archetype bundled in the
# COLNEC blood-pressure template). Field names drive `t.float :<name>` in
# migrations and `validates :<name>` in models, so they must be sanitised to
# valid identifiers. These specs pin that, again using lightweight doubles so
# they don't depend on a particular openehr gem build.
describe OpenehrRails::Opt::FieldExtractor do
  describe 'an entry whose archetype concept contains a hyphen' do
    def attribute(name, children)
      OpenStruct.new(rm_attribute_name: name, children: children)
    end

    let(:element) do
      OpenStruct.new(
        rm_type_name: 'ELEMENT',
        node_id: 'at0004',
        occurrences: OpenStruct.new(lower: 1),
        attributes: [attribute('value', [OpenStruct.new(rm_type_name: 'DV_QUANTITY')])]
      )
    end

    let(:observation) do
      OpenStruct.new(
        rm_type_name: 'OBSERVATION',
        node_id: 'at0000',
        archetype_id: OpenStruct.new(value: 'openEHR-EHR-OBSERVATION.heart_rate-pulse.v1'),
        occurrences: OpenStruct.new(lower: 1),
        attributes: [attribute('data', [element])]
      )
    end

    let(:template) do
      OpenStruct.new(
        definition: OpenStruct.new(attributes: [attribute('content', [observation])]),
        component_terminologies: {}
      )
    end

    let(:extractor) { described_class.new(template) }

    it 'sanitises the concept to a valid identifier' do
      expect(extractor.entries.map { |e| e[:concept] }).to eq(%w[heart_rate_pulse])
    end

    it 'produces a hyphen-free field name usable as a column/attribute' do
      name = extractor.fields.map { |f| f[:name] }.first
      expect(name).to eq('heart_rate_pulse')
      expect(name).to match(/\A[a-z_][a-z0-9_]*\z/)
    end
  end
end

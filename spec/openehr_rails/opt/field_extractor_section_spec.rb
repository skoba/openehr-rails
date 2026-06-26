require 'spec_helper'
require 'openehr_rails'
require 'ostruct'

# Vitals / general-examination templates organise their ENTRYs inside one or
# more SECTIONs rather than hanging them directly off /content. These specs
# pin the FieldExtractor's descent through SECTION containers without depending
# on a particular openehr gem build: the constraint tree is assembled from
# lightweight doubles that expose just the methods the extractor touches.
describe OpenehrRails::Opt::FieldExtractor do
  describe 'entries nested inside a SECTION' do
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
        archetype_id: OpenStruct.new(value: 'openEHR-EHR-OBSERVATION.body_temperature.v2'),
        occurrences: OpenStruct.new(lower: 1),
        attributes: [attribute('data', [element])]
      )
    end

    let(:section) do
      OpenStruct.new(
        rm_type_name: 'SECTION',
        archetype_id: OpenStruct.new(value: 'openEHR-EHR-SECTION.vitals.v1'),
        attributes: [attribute('items', [observation])]
      )
    end

    let(:template) do
      OpenStruct.new(
        definition: OpenStruct.new(attributes: [attribute('content', [section])]),
        component_terminologies: {}
      )
    end

    let(:extractor) { described_class.new(template) }

    it 'finds the ENTRY nested under the SECTION' do
      expect(extractor.entries.map { |e| e[:archetype_id] })
        .to eq(['openEHR-EHR-OBSERVATION.body_temperature.v2'])
    end

    it 'extracts the nested element as a field' do
      expect(extractor.fields.map { |f| f[:name] }).to eq(['body_temperature'])
    end

    it 'threads the SECTION into the RM path' do
      expect(extractor.fields.first[:path]).to eq(
        '/content[openEHR-EHR-SECTION.vitals.v1]' \
        '/items[openEHR-EHR-OBSERVATION.body_temperature.v2]' \
        '/data[at0004]/value'
      )
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Rm::Composition do
  it 'requires uid and archetype_node_id' do
    composition = described_class.new
    expect(composition).not_to be_valid
    expect(composition.errors[:uid]).not_to be_empty
    expect(composition.errors[:archetype_node_id]).not_to be_empty
  end

  it 'scopes to the latest version' do
    head = described_class.create!(uid: 'u1', archetype_node_id: 'a')
    described_class.create!(uid: 'u1', archetype_node_id: 'a', latest_version: false)

    expect(described_class.latest).to eq([head])
  end

  it 'orders content nodes by position' do
    composition = described_class.create!(uid: 'u1', archetype_node_id: 'a')
    second = OpenehrRails::Rm::Observation.create!(
      composition: composition, rm_attribute_name: 'content', position: 1,
      archetype_id: 'b', path: '/content[b]'
    )
    first = OpenehrRails::Rm::Observation.create!(
      composition: composition, rm_attribute_name: 'content', position: 0,
      archetype_id: 'a', path: '/content[a]'
    )

    expect(composition.content_nodes).to eq([first, second])
  end

  it 'purges its graph rows' do
    composition = described_class.create!(uid: 'u1', archetype_node_id: 'a')
    element = OpenehrRails::Rm::Element.create!(
      composition: composition, rm_attribute_name: 'items', path: '/p'
    )
    OpenehrRails::Rm::DvText.create!(
      node: element, composition: composition, path: '/p/value', text_value: 'x'
    )

    composition.purge_graph!
    expect(OpenehrRails::Rm::Node.where(composition_id: composition.id)).to be_empty
    expect(OpenehrRails::Rm::DataValue.where(composition_id: composition.id)).to be_empty
  end
end

describe OpenehrRails::Rm::Ehr do
  it 'requires a unique ehr_id and fills time_created' do
    ehr = described_class.create!(ehr_id: 'patient-1')
    expect(ehr.time_created).to be_present
    expect(described_class.new(ehr_id: 'patient-1')).not_to be_valid
  end

  it 'has compositions' do
    ehr = described_class.create!(ehr_id: 'patient-1')
    composition = OpenehrRails::Rm::Composition.create!(
      uid: 'u1', archetype_node_id: 'a', ehr: ehr
    )
    expect(ehr.compositions).to eq([composition])
  end
end

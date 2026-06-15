# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Rm::Node do
  let(:composition) do
    OpenehrRails::Rm::Composition.create!(
      uid: 'uid-1', archetype_node_id: 'openEHR-EHR-COMPOSITION.report-result.v1'
    )
  end

  it 'round-trips STI through openEHR type names' do
    node = OpenehrRails::Rm::Observation.create!(
      composition: composition, rm_attribute_name: 'content',
      archetype_node_id: 'openEHR-EHR-OBSERVATION.height.v2',
      archetype_id: 'openEHR-EHR-OBSERVATION.height.v2',
      path: '/content[openEHR-EHR-OBSERVATION.height.v2]'
    )

    expect(node.rm_type).to eq('OBSERVATION')
    expect(OpenehrRails::Rm::Node.find(node.id)).to be_a(OpenehrRails::Rm::Observation)
  end

  it 'orders children by position' do
    parent = OpenehrRails::Rm::ItemTree.create!(
      composition: composition, rm_attribute_name: 'data', path: '/x/data[at0003]'
    )
    second = OpenehrRails::Rm::Element.create!(
      composition: composition, parent: parent, rm_attribute_name: 'items',
      position: 1, path: '/x/data[at0003]/items[at0005]'
    )
    first = OpenehrRails::Rm::Element.create!(
      composition: composition, parent: parent, rm_attribute_name: 'items',
      position: 0, path: '/x/data[at0003]/items[at0004]'
    )

    expect(parent.children).to eq([first, second])
  end

  it 'requires rm_attribute_name and path' do
    node = OpenehrRails::Rm::Element.new(composition: composition)
    expect(node).not_to be_valid
    expect(node.errors[:rm_attribute_name]).not_to be_empty
    expect(node.errors[:path]).not_to be_empty
  end

  it 'requires archetype_id on entry nodes' do
    entry = OpenehrRails::Rm::Observation.new(
      composition: composition, rm_attribute_name: 'content', path: '/content[x]'
    )
    expect(entry).not_to be_valid
    expect(entry.errors[:archetype_id]).not_to be_empty
  end

  it 'requires width on interval events' do
    event = OpenehrRails::Rm::IntervalEvent.new(
      composition: composition, rm_attribute_name: 'events', path: '/x/events[at0002]'
    )
    expect(event).not_to be_valid
    expect(event.errors[:width]).not_to be_empty
  end
end

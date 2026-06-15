# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../storable_spec_model'

describe OpenehrRails::Rm::GraphBuilder do
  let(:record) { BmiCalculation.create!(height: 170.0, body_weight: 65.0) }
  let(:builder) { described_class.new(record.rm_composition) }
  let(:composition) do
    OpenehrRails::Rm::Composition.create!(
      builder.composition_attributes.merge(uid: record.uid)
    )
  end

  before { builder.build!(composition) }

  it 'extracts composition attributes from the canonical hash' do
    attrs = builder.composition_attributes
    expect(attrs[:archetype_node_id]).to eq('openEHR-EHR-COMPOSITION.report-result.v1')
    expect(attrs[:template_id]).to eq('bmi_calculation')
  end

  it 'creates one entry node per content entry' do
    entries = composition.content_nodes
    expect(entries.map(&:class)).to eq([OpenehrRails::Rm::Observation] * 2)
    expect(entries.map(&:archetype_id)).to contain_exactly(
      'openEHR-EHR-OBSERVATION.height.v2', 'openEHR-EHR-OBSERVATION.body_weight.v2'
    )
  end

  it 'builds the typed structure tree' do
    height = composition.content_nodes
                        .find { |n| n.archetype_id == 'openEHR-EHR-OBSERVATION.height.v2' }
    history = height.children.first
    event = history.children.first
    tree = event.children.first
    element = tree.children.first

    expect(history).to be_a(OpenehrRails::Rm::History)
    expect(event).to be_a(OpenehrRails::Rm::PointEvent)
    expect(tree).to be_a(OpenehrRails::Rm::ItemTree)
    expect(element).to be_a(OpenehrRails::Rm::Element)
    expect(element.archetype_node_id).to eq('at0004')
  end

  it 'computes FIELD_MAP-compatible paths' do
    element_path = BmiCalculation::FIELD_MAP['height'][:path].delete_suffix('/value')
    element = composition.nodes.find_by(path: element_path)
    expect(element).to be_a(OpenehrRails::Rm::Element)

    dv = composition.data_values.find_by(path: BmiCalculation::FIELD_MAP['height'][:path])
    expect(dv).to be_a(OpenehrRails::Rm::DvQuantity)
  end

  it 'stores data values with typed columns' do
    dv = composition.data_values.find_by(path: BmiCalculation::FIELD_MAP['height'][:path])
    expect(dv.magnitude).to eq(170.0)
    expect(dv.units).to eq('cm')
    expect(dv.node.archetype_node_id).to eq('at0004')
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../storable_spec_model'

describe 'AQL path search on the RM graph' do
  let!(:record) { BmiCalculation.create!(height: 170.0) }
  let(:extra_path) do
    '/content[openEHR-EHR-OBSERVATION.height.v2]' \
      '/data[at0001]/events[at0002]/data[at0003]/items[at0099]/value'
  end

  def add_extra_element(composition, magnitude: 7.5)
    tree = composition.nodes.find_by(rm_type: 'ITEM_TREE')
    element = OpenehrRails::Rm::Element.create!(
      composition: composition, parent: tree, rm_attribute_name: 'items',
      position: 1, archetype_node_id: 'at0099',
      path: extra_path.delete_suffix('/value')
    )
    OpenehrRails::Rm::DvQuantity.create!(
      node: element, composition: composition, path: extra_path,
      magnitude: magnitude, units: 'mm'
    )
  end

  it 'still resolves FIELD_MAP paths through typed columns' do
    height_path = BmiCalculation::FIELD_MAP['height'][:path]
    expect(BmiCalculation.find_by_path(height_path, 170.0)).to eq([record])
  end

  it 'finds records through graph paths not present in FIELD_MAP' do
    add_extra_element(record.rm_graph)

    expect(BmiCalculation.find_by_path(extra_path, 7.5)).to eq([record])
    expect(BmiCalculation.find_by_path(extra_path, 9.9)).to be_empty
  end

  it 'matches only against the head version' do
    add_extra_element(record.rm_graph)
    record.update!(height: 168.0) # new head graph lacks the extra element

    expect(BmiCalculation.find_by_path(extra_path, 7.5)).to be_empty
  end

  it 'raises for unknown paths when the graph layer is disabled' do
    OpenehrRails.rm_persistence_enabled = false
    expect { BmiCalculation.find_by_path('/content[nowhere]/value', 1) }
      .to raise_error(ArgumentError, /no field maps/)
  ensure
    OpenehrRails.rm_persistence_enabled = nil
  end

  it 'returns an empty relation for unmatched graph paths' do
    expect(BmiCalculation.find_by_path('/content[nowhere]/value', 1)).to be_empty
  end
end

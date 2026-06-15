# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Rm::TypeMap do
  it 'maps node classes to openEHR type names' do
    expect(described_class.rm_type_for(OpenehrRails::Rm::Observation)).to eq('OBSERVATION')
    expect(described_class.rm_type_for(OpenehrRails::Rm::ItemTree)).to eq('ITEM_TREE')
    expect(described_class.rm_type_for(OpenehrRails::Rm::PointEvent)).to eq('POINT_EVENT')
  end

  it 'maps data value classes to openEHR type names' do
    expect(described_class.rm_type_for(OpenehrRails::Rm::DvQuantity)).to eq('DV_QUANTITY')
    expect(described_class.rm_type_for(OpenehrRails::Rm::DvCodedText)).to eq('DV_CODED_TEXT')
  end

  it 'resolves node classes from type names' do
    expect(described_class.node_class_for('OBSERVATION')).to eq(OpenehrRails::Rm::Observation)
    expect(described_class.node_class_for('CLUSTER')).to eq(OpenehrRails::Rm::Cluster)
  end

  it 'resolves data value classes from type names' do
    expect(described_class.data_value_class_for('DV_TEXT')).to eq(OpenehrRails::Rm::DvText)
    expect(described_class.data_value_class_for('DV_BOOLEAN')).to eq(OpenehrRails::Rm::DvBoolean)
  end

  it 'raises for unknown type names' do
    expect { described_class.node_class_for('NOPE') }
      .to raise_error(ArgumentError, /unknown RM node type/)
    expect { described_class.data_value_class_for('DV_NOPE') }
      .to raise_error(ArgumentError, /unknown RM data value type/)
  end
end

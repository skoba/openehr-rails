# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'

describe 'OpenehrRails::AqlQueryable.aql' do
  let(:height_query) do
    'SELECT o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude AS height ' \
      'FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2]'
  end

  it 'executes an AQL query scoped to compositions owned by this model' do
    BmiCalculation.create!(height: 170.0)

    expect(BmiCalculation.aql(height_query).rows).to eq([[170.0]])
  end

  it 'does not see compositions owned by another model class' do
    record = BmiCalculation.create!(height: 170.0)
    other_composition = record.rm_graph
    other_composition.update!(owner_type: 'SomeOtherModel')

    expect(BmiCalculation.aql(height_query).rows).to eq([])
  end
end

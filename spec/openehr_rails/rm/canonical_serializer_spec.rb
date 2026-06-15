# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../storable_spec_model'

describe OpenehrRails::Rm::CanonicalSerializer do
  let(:record) { BmiCalculation.create!(height: 170.0, body_weight: 65.0) }

  # The FHIR-safety contract: a graph built from the canonical hash must
  # serialize back to a deep-equal hash.
  it 'round-trips the canonical composition hash losslessly' do
    builder = OpenehrRails::Rm::GraphBuilder.new(record.rm_composition)
    composition = OpenehrRails::Rm::Composition.create!(
      builder.composition_attributes.merge(uid: record.uid)
    )
    builder.build!(composition)

    expect(composition.to_canonical_hash).to eq(record.rm_composition)
  end

  it 'round-trips coded text and boolean values' do
    canonical = {
      '_type' => 'COMPOSITION',
      'archetype_node_id' => 'openEHR-EHR-COMPOSITION.test.v1',
      'archetype_details' => {
        '_type' => 'ARCHETYPED',
        'archetype_id' => { 'value' => 'openEHR-EHR-COMPOSITION.test.v1' },
        'template_id' => { 'value' => 'test' },
        'rm_version' => '1.0.4'
      },
      'content' => [
        {
          '_type' => 'EVALUATION',
          'archetype_node_id' => 'openEHR-EHR-EVALUATION.sample.v1',
          'archetype_details' => {
            '_type' => 'ARCHETYPED',
            'archetype_id' => { 'value' => 'openEHR-EHR-EVALUATION.sample.v1' },
            'rm_version' => '1.0.4'
          },
          'data' => {
            '_type' => 'ITEM_TREE',
            'archetype_node_id' => 'at0001',
            'items' => [
              {
                'archetype_node_id' => 'at0002',
                '_type' => 'ELEMENT',
                'value' => {
                  '_type' => 'DV_CODED_TEXT',
                  'value' => 'Present',
                  'defining_code' => {
                    '_type' => 'CODE_PHRASE',
                    'terminology_id' => { 'value' => 'local' },
                    'code_string' => 'at0010'
                  }
                }
              },
              {
                'archetype_node_id' => 'at0003',
                '_type' => 'ELEMENT',
                'value' => { '_type' => 'DV_BOOLEAN', 'value' => true }
              }
            ]
          }
        }
      ]
    }

    builder = OpenehrRails::Rm::GraphBuilder.new(canonical)
    composition = OpenehrRails::Rm::Composition.create!(
      builder.composition_attributes.merge(uid: 'u-test')
    )
    builder.build!(composition)

    expect(composition.to_canonical_hash.except('uid')).to eq(canonical)
  end
end

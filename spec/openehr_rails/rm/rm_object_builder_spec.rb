# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../storable_spec_model'

describe OpenehrRails::Rm::RmObjectBuilder do
  let(:record) { BmiCalculation.create!(height: 170.0) }
  let(:composition) { record.rm_graph }
  let(:rm_composition) { composition.to_rm }

  it 'builds a valid OpenEHR::RM::Composition' do
    expect(rm_composition).to be_a(OpenEHR::RM::Composition::Composition)
  end

  it 'sets mandatory composition attributes' do
    expect(rm_composition.archetype_node_id)
      .to eq('openEHR-EHR-COMPOSITION.report-result.v1')
    expect(rm_composition.uid).to be_a(OpenEHR::RM::Support::Identification::HierObjectID)
    expect(rm_composition.uid.value).to eq(composition.uid)
    expect(rm_composition.language).to be_a(OpenEHR::RM::DataTypes::Text::CodePhrase)
    expect(rm_composition.language.code_string).to eq('en')
    expect(rm_composition.territory).to be_a(OpenEHR::RM::DataTypes::Text::CodePhrase)
    expect(rm_composition.category).to be_a(OpenEHR::RM::DataTypes::Text::DvCodedText)
    expect(rm_composition.composer).to be_a(OpenEHR::RM::Common::Generic::PartyIdentified)
  end

  it 'injects config defaults for missing attributes' do
    expect(rm_composition.language.code_string).to eq(OpenehrRails.default_language)
    expect(rm_composition.territory.code_string).to eq(OpenehrRails.default_territory)
    # Category is DvCodedText; config gives [code, value, terminology]
    expect(rm_composition.category.value).to eq('433')
    expect(rm_composition.category.defining_code.code_string).to eq('event')
    expect(rm_composition.composer.name).to eq(OpenehrRails.default_composer_name)
  end

  it 'builds entry structures' do
    expect(rm_composition.content.count).to eq(1)
    obs = rm_composition.content.first
    expect(obs).to be_a(OpenEHR::RM::Composition::Content::Entry::Observation)
  end

  it 'builds history and events' do
    obs = rm_composition.content.first
    history = obs.data
    expect(history).to be_a(OpenEHR::RM::DataStructures::History::History)
    expect(history.events.count).to be > 0
  end

  it 'builds leaf data values with correct types' do
    obs = rm_composition.content.first
    event = obs.data.events.first
    data = event.data
    element = data.items.first

    expect(element.value).to be_a(OpenEHR::RM::DataTypes::Quantity::DvQuantity)
    expect(element.value.magnitude).to eq(170.0)
    expect(element.value.units).to eq('cm')
  end

  it 'always generates a valid composition by injecting all defaults' do
    # Even a minimal composition graph becomes a valid RM object
    # thanks to config defaults
    bad_comp = OpenehrRails::Rm::Composition.create!(
      uid: 'u-bad', archetype_node_id: 'x'
    )
    bad_comp.update_columns(
      language_code: nil, territory_code: nil,
      category_code: nil, composer_name: nil
    )

    result = bad_comp.to_rm
    expect(result).to be_a(OpenEHR::RM::Composition::Composition)
    expect(result.language.code_string).to eq(OpenehrRails.default_language)
  end

  # skoba/openehr-rails#44 (a) bug: a node type the graph stores but
  # TYPE_CLASSES lacks used to surface as `NoMethodError: undefined method
  # 'new' for nil`. The typed error names what the caller needs to act on.
  it 'raises UnsupportedRmTypeError, naming composition and node, for an rm_type outside TYPE_CLASSES' do
    composition = OpenehrRails::Rm::CompositionCommitter.commit(
      {
        '_type' => 'COMPOSITION',
        'archetype_node_id' => 'openEHR-EHR-COMPOSITION.synthetic_section_test.v1',
        'content' => [
          { '_type' => 'SECTION', 'archetype_node_id' => 'openEHR-EHR-SECTION.synthetic_test.v1', 'items' => [] }
        ]
      },
      uid: 'uid-section-builder'
    )

    expect { composition.to_rm }.to raise_error(OpenehrRails::Rm::UnsupportedRmTypeError) { |error|
      expect(error.message).to include('uid-section-builder', 'SECTION', 'openEHR-EHR-SECTION.synthetic_test.v1')
      expect(error.rm_type).to eq('SECTION')
    }
  end
end

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
  # Since #45 SECTION is buildable, so the unsupported type here is an
  # ITEM_TABLE as an EVALUATION's data (ruling condition (c)).
  it 'raises UnsupportedRmTypeError, naming composition and node, for an rm_type outside TYPE_CLASSES' do
    composition = OpenehrRails::Rm::CompositionCommitter.commit(
      {
        '_type' => 'COMPOSITION',
        'archetype_node_id' => 'openEHR-EHR-COMPOSITION.synthetic_table_test.v1',
        'content' => [
          {
            '_type' => 'EVALUATION', 'archetype_node_id' => 'openEHR-EHR-EVALUATION.synthetic_table_test.v1',
            'archetype_details' => { 'archetype_id' => { 'value' => 'openEHR-EHR-EVALUATION.synthetic_table_test.v1' } },
            'data' => { '_type' => 'ITEM_TABLE', 'archetype_node_id' => 'at0001', 'rows' => [] }
          }
        ]
      },
      uid: 'uid-table-builder'
    )

    expect { composition.to_rm }.to raise_error(OpenehrRails::Rm::UnsupportedRmTypeError) { |error|
      expect(error.message).to include('uid-table-builder', 'ITEM_TABLE', 'data[at0001]')
      expect(error.rm_type).to eq('ITEM_TABLE')
    }
  end

  # skoba/openehr-rails#45, resolution shape (b) enhancement: SECTION,
  # INSTRUCTION and ACTIVITY nodes -- persisted by GraphBuilder all along --
  # are rebuilt as RM objects. Fixture: spec/support/synthetic_referral_canonical_hash.rb
  # (synthetic; design authority docs/design/rm-object-builder-section-instruction-plan.md
  # section 3). Red before #45: UnsupportedRmTypeError on the SECTION.
  describe 'SECTION, INSTRUCTION and ACTIVITY (#45)' do
    let(:fixture) { SyntheticReferralCanonicalHash }
    let(:rm) do
      OpenehrRails::Rm::CompositionCommitter.commit(fixture.composition, uid: 'uid-referral').to_rm
    end

    it 'rebuilds a SECTION with its items' do
      section = rm.content.first

      expect(section).to be_a(OpenEHR::RM::Composition::Content::Navigation::Section)
      expect(section.archetype_node_id).to eq(fixture::SECTION_ID)
      expect(section.items.size).to eq(1)
      expect(section.items.first).to be_a(OpenEHR::RM::Composition::Content::Entry::Evaluation)
      expect(section.items.first.data.items.first.value.value).to eq('stable')
    end

    it 'rebuilds an INSTRUCTION with entry defaults, narrative, protocol and activities' do
      instruction = rm.content.last

      expect(instruction).to be_a(OpenEHR::RM::Composition::Content::Entry::Instruction)
      expect(instruction.language.code_string).to eq(OpenehrRails.default_language)
      expect(instruction.narrative.value).to eq('Refer to cardiology')
      expect(instruction.protocol.items.first.value.value).to eq('Synthetic Hospital')
      expect(instruction.activities.size).to eq(1)
    end

    it 'rebuilds an ACTIVITY with description, timing and the injected action_archetype_id' do
      activity = rm.content.last.activities.first

      expect(activity).to be_a(OpenEHR::RM::Composition::Content::Entry::Activity)
      expect(activity.archetype_node_id).to eq('at0001')
      expect(activity.description.items.first.value.value).to eq('Chest pain work-up')
      expect(activity.timing).to be_a(OpenEHR::RM::DataTypes::Encapsulated::DvParsable)
      expect(activity.timing.value).to eq('R1')
      expect(activity.timing.formalism).to eq('timing')
      # Approximation (ruling condition (a)): the graph does not carry
      # action_archetype_id yet, so the RM's "any ACTION archetype" pattern is
      # injected; phase B persists the real value.
      expect(activity.action_archetype_id).to eq('/.*/')
    end

    # Approximation (ruling condition (a)): narrative is mandatory on the RM
    # INSTRUCTION; when the graph has no narrative row, the node's name stands
    # in. Phase B persists it as a column.
    it 'injects the node name as narrative when the graph has none' do
      composition = OpenehrRails::Rm::CompositionCommitter.commit(
        fixture.composition(content: [fixture.instruction(narrative: false)]), uid: 'uid-referral-no-narrative'
      )

      expect(composition.to_rm.content.first.narrative.value).to eq('Request')
    end

    it 'builds a SECTION without items as items nil (the RM rejects an empty list)' do
      composition = OpenehrRails::Rm::CompositionCommitter.commit(
        fixture.composition(content: [fixture.section([])]), uid: 'uid-referral-empty-section'
      )

      expect(composition.to_rm.content.first.items).to be_nil
    end

    # Ruling condition (b): restoring `protocol` for every CARE_ENTRY must not
    # change what an entry without a protocol node rebuilds to.
    # Regression pin -- this was already true before #45.
    it 'leaves protocol nil on an OBSERVATION that has no protocol node' do
      expect(BmiCalculation.create!(height: 170.0).rm_graph.to_rm.content.first.protocol).to be_nil
    end
  end
end

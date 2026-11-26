# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative 'support/storable_models'

# Issue #62 (plan docs/design/0.9.x-plan.md 3.1a, 3.3): entries nested in a
# SECTION are written inside a SECTION node under content, and two instances of
# one entry archetype stay two entries.
describe OpenehrRails::Storable do
  include StorableModels

  let(:section_id) { 'openEHR-EHR-SECTION.referral_details.v0' }
  let(:synopsis_id) { 'openEHR-EHR-EVALUATION.clinical_synopsis.v1' }
  let(:model) { storable_model(:section_jp_referrals, field_map_for('templates/jp_referral.opt')) }
  let(:record) do
    model.create!('story' => '胸痛', 'clinical_synopsis' => '一つめ', 'clinical_synopsis_2' => '二つめ',
                  'problem_diagnosis_at0002' => 'at0.1')
  end
  let(:section) { record.rm_composition['content'].sole }

  # bug: red before #62 (refused by the #60 guard; before the guard, no SECTION node).
  it 'writes one SECTION under content, with its archetype details' do
    expect(section).to include('_type' => 'SECTION', 'archetype_node_id' => section_id,
                               'archetype_details' => include('archetype_id' => { 'value' => section_id }))
  end

  # bug: red before #62.
  it 'puts the entries in the SECTION items, in template order, the repeated entry twice' do
    expect(section['items'].pluck('_type', 'archetype_node_id')).to eq(
      [%w[EVALUATION openEHR-EHR-EVALUATION.problem_diagnosis.v1], %w[OBSERVATION openEHR-EHR-OBSERVATION.story.v1],
       ['EVALUATION', synopsis_id], ['EVALUATION', synopsis_id]]
    )
  end

  # bug: red before #62 (the two clinical_synopsis values collapsed into one entry).
  it 'keeps each repeated entry\'s own value' do
    synopses = section['items'].select { |entry| entry['archetype_node_id'] == synopsis_id }

    expect(synopses.map { |entry| entry.dig('data', 'items', 0, 'value', 'value') }).to eq(%w[一つめ 二つめ])
  end

  # bug: red before #62.
  it 'rebuilds the persisted graph as RM objects with the SECTION in place' do
    rm_section = record.rm_graph.to_rm.content.sole

    expect(rm_section).to be_a(OpenEHR::RM::Composition::Content::Navigation::Section)
    expect(rm_section.items.map(&:archetype_node_id).tally).to include(synopsis_id => 2)
  end

  # enhancement (#69): the INSTRUCTION in the same SECTION saves too (refused
  # until #69; spec/openehr_rails/storable_instruction_spec.rb has the details).
  it 'puts the INSTRUCTION in the same SECTION' do
    saved = model.create!('service_request_at0121' => '紹介', 'story' => '胸痛')

    expect(saved.rm_composition['content'].sole['items'].pluck('_type')).to eq(%w[INSTRUCTION OBSERVATION])
  end

  describe 'a repeated entry directly under content (bmi_calculation_repeated_root)' do
    let(:bmi) { storable_model(:section_repeated_bmis, field_map_for('templates/bmi_calculation_repeated_root.opt')) }

    # regression pin: fixed by #61's root_chain grouping (PR #87, master 36ba264). On
    # master 2dfbb37 it was red: got [23.5], the second instance overwrote the first.
    it 'writes two OBSERVATIONs, each with its own value' do
      record = bmi.create!('body_mass_index' => '22.5', 'body_mass_index_2' => '23.5')
      bmis = record.rm_composition['content'].select { |entry| entry['archetype_node_id'].include?('body_mass_index') }

      expect(bmis.map { |entry| entry.dig('data', 'events', 0, 'data', 'items', 0, 'value', 'magnitude') })
        .to eq([22.5, 23.5])
    end
  end

  describe 'a FIELD_MAP generated before root_chain' do
    let(:legacy) do
      storable_model(:section_jp_referrals_legacy,
                     field_map_for('templates/jp_referral.opt').transform_values { |field| field.except(:root_chain) })
    end

    # bug: red before #62.
    it 'saves an entry that does not repeat' do
      expect(legacy.create!('story' => '胸痛').rm_composition['content'].sole['items'].sole['archetype_node_id'])
        .to eq('openEHR-EHR-OBSERVATION.story.v1')
    end

    # enhancement (#62): the instances of a repeated entry cannot be told apart without root_chain.
    it 'refuses a value for a repeated entry, asking for a re-scaffold' do
      expect { legacy.create!('clinical_synopsis_2' => '二つめ') }.to raise_error(
        OpenehrRails::Storable::UnsupportedTemplateShape, /re-scaffold/
      )
    end
  end
end

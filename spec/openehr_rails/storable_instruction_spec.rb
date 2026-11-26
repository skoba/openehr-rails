# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative 'support/storable_models'
require_relative 'support/action_archetype_constraint'

# Issue #69 (plan docs/design/0.9.x-plan.md 3.4, 3.4a): an INSTRUCTION is
# written with its narrative (the filled elements as "label: value", joined by
# a full-width semicolon) and each ACTIVITY with its action_archetype_id, and
# the graph rebuilds both without the 0.8.0 approximations.
describe OpenehrRails::Storable do
  include StorableModels
  include ActionArchetypeConstraint

  let(:model) { storable_model(:instruction_jp_referrals, field_map_for('templates/jp_referral.opt')) }
  let(:values) do
    { 'service_request_at0121' => '循環器内科受診', 'service_request_at0062' => '精査のお願い',
      'organisation_at0001' => 'A病院', 'address_at0002' => '文京区', 'organisation_at0001_2' => 'B病院' }
  end
  let(:record) { model.create!(values) }
  let(:instruction) { record.rm_composition['content'].sole['items'].sole }
  let(:narrative) do
    'サービス名: 循環器内科受診；紹介目的: 精査のお願い；紹介元医療機関／名称: A病院；住所／市区町村: 文京区；' \
      '紹介先医療機関／名称: B病院'
  end

  # enhancement: red before #69 (refused by the #60 guard).
  it 'writes the narrative from the filled elements, in template order' do
    expect(instruction).to include('_type' => 'INSTRUCTION', 'archetype_node_id' => 'openEHR-EHR-INSTRUCTION.service_request.v1',
                                   'narrative' => { '_type' => 'DV_TEXT', 'value' => narrative })
  end

  # enhancement: red before #69.
  it 'writes the ACTIVITY with its description and action_archetype_id' do
    activity = instruction['activities'].sole

    expect(activity).to include('_type' => 'ACTIVITY', 'action_archetype_id' => '/.*/')
    expect(activity.dig('description', 'items').map { |item| item.dig('value', 'value') })
      .to eq(%w[循環器内科受診 精査のお願い])
  end

  # enhancement: red before #69.
  it 'keeps the two organisation roots in the protocol apart' do
    roots = instruction.dig('protocol', 'items')
                       .select { |item| item['archetype_node_id'] == 'openEHR-EHR-CLUSTER.organisation.v1' }

    expect(roots.map { |root| root['items'].find { |item| item['archetype_node_id'] == 'at0001' }.dig('value', 'value') })
      .to eq(%w[A病院 B病院])
  end

  # enhancement: red before #69 (to_rm used the node name as narrative).
  it 'rebuilds the narrative from the graph' do
    expect(record.rm_graph.to_rm.content.sole.items.sole.narrative.value).to eq(narrative)
  end

  # enhancement: red before #69.
  it 'labels a coded value by its display text in the narrative' do
    field = model::FIELD_MAP['electronic_communication_at0001']
    code = field[:code_list].first
    saved = model.create!(values.slice('service_request_at0121').merge('electronic_communication_at0001' => code))

    expect(saved.rm_composition['content'].sole['items'].sole.dig('narrative', 'value'))
      .to eq("サービス名: 循環器内科受診；電子的な連絡先／種別: #{field[:code_labels][code]}")
  end

  describe 'an OPT that constrains action_archetype_id' do
    let(:constrained) do
      template = OpenehrRails::Opt.parse(File.expand_path('../templates/jp_referral.opt', __dir__))
      constrain_action_archetype_id(template, 'openEHR-EHR-ACTION\.service\.v1')
      fields = OpenehrRails::Opt::FieldExtractor.new(template).fields.index_by { |field| field[:name] }
      storable_model(:instruction_constrained_referrals, fields.freeze)
    end

    # enhancement: red before #69 (to_rm injected '/.*/').
    it 'stores the pattern and rebuilds it from the graph' do
      saved = constrained.create!(values.slice('service_request_at0121'))

      expect(saved.rm_graph.to_rm.content.sole.items.sole.activities.sole.action_archetype_id)
        .to eq('/openEHR-EHR-ACTION\.service\.v1/')
    end
  end

  # regression pin: an INSTRUCTION with no filled element is not written.
  it 'writes no INSTRUCTION when none of its elements is filled' do
    expect(model.create!('story' => '胸痛').rm_composition['content'].sole['items'].pluck('_type')).to eq(['OBSERVATION'])
  end
end

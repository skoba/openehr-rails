# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../support/action_archetype_constraint'

# Issue #69 (plan docs/design/0.9.x-plan.md 3.4, 3.4a): the keys Storable needs
# to assemble an INSTRUCTION -- root_label for the narrative, and the ACTIVITY's
# action_archetype_id.
describe OpenehrRails::Opt::FieldExtractor do
  include ActionArchetypeConstraint

  let(:template) { OpenehrRails::Opt.parse(File.expand_path('../../templates/jp_referral.opt', __dir__)) }
  let(:fields) { described_class.new(template).fields.index_by { |field| field[:name] } }

  # enhancement: red before #69 (no such key).
  it 'gives a field under an embedded root the template name of that root instance as root_label' do
    expect(fields.values_at('address_at0002', 'organisation_at0001', 'organisation_at0001_2', 'person_at0001_2')
                 .pluck(:root_label)).to eq(%w[住所 紹介元医療機関 紹介先医療機関 担当医])
  end

  # enhancement: red before #69.
  it 'gives an entry-owned field no root_label' do
    expect(fields['service_request_at0121']).not_to have_key(:root_label)
  end

  # enhancement: red before #69 (no such key).
  it 'gives a field under an ACTIVITY the any-ACTION pattern when the OPT does not constrain it' do
    expect(fields['service_request_at0121'][:action_archetype_id]).to eq('/.*/')
  end

  # enhancement: red before #69.
  it 'gives a field outside the activities no action_archetype_id' do
    expect(fields['organisation_at0001']).not_to have_key(:action_archetype_id)
  end

  # enhancement: red before #69. The constraint is added to the parsed tree: no
  # fixture constrains action_archetype_id (plan 3.4a).
  it 'takes the ACTIVITY\'s action_archetype_id pattern from the OPT when there is one' do
    constrain_action_archetype_id(template, 'openEHR-EHR-ACTION\.service\.v1')

    expect(fields['service_request_at0121'][:action_archetype_id]).to eq('/openEHR-EHR-ACTION\.service\.v1/')
  end
end

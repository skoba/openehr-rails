# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr_rails'
require_relative '../storable_spec_model'

# #124 (R-20261128-9): a committed COMPOSITION.category is stored in the
# existing category_code / category_value columns and returned by REST and
# to_rm as committed. No migration. A composition committed without one keeps
# the configured default (OpenehrRails.default_category).
describe OpenehrRails::Rm::CompositionCommitter do
  let(:ehr) { OpenehrRails::Rm::Ehr.find_or_create_by!(ehr_id: 'ehr-124') }
  let(:persistent) do
    { '_type' => 'DV_CODED_TEXT', 'value' => 'persistent',
      'defining_code' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { 'value' => 'openehr' },
                           'code_string' => '431' } }
  end

  def canonical(category: nil)
    hash = BmiCalculation.new(height: 170.0, composed_at: Time.utc(2026, 3, 1)).to_rm_composition.deep_stringify_keys
    hash['category'] = category if category
    hash
  end

  def commit(hash, **options)
    described_class.commit(hash, uid: SecureRandom.uuid, ehr: ehr, **options)
  end

  describe 'a committed category' do
    # bug: red before #124 (both columns stayed nil).
    it 'is stored in category_code and category_value' do
      composition = commit(canonical(category: persistent))

      expect(composition.reload).to have_attributes(category_code: '431', category_value: 'persistent')
    end

    # bug: red before #124 (REST returned no category).
    it 'is returned by REST as committed' do
      expect(commit(canonical(category: persistent)).to_canonical_hash['category']).to eq(persistent)
    end

    # bug: red before #124 (to_rm gave 433 event).
    it 'is rebuilt by to_rm as committed' do
      category = commit(canonical(category: persistent)).to_rm.category

      expect([category.defining_code.code_string, category.value]).to eq(%w[431 persistent])
    end

    # bug: red before #124 (#121's context rule read the configured category
    # only): a persistent composition whose context came only from the
    # keyword gets no added context.
    it 'decides whether a keyword-only context is added (none for persistent)' do
      composition = commit(canonical(category: persistent), context_start_time: Time.utc(2026, 3, 1))

      expect(composition.to_canonical_hash).not_to have_key('context')
    end
  end

  describe 'a composition committed without a category' do
    # bug: red before #124 (default_category [code, value] went in as
    # [value, code]: code_string 'event', value '433').
    it 'rebuilds the configured default through to_rm' do
      category = commit(canonical).to_rm.category

      expect([category.defining_code.code_string, category.value]).to eq(%w[433 event])
    end

    # regression pin: REST writes no category it was not given.
    it 'returns no category through REST, and keeps the columns nil' do
      composition = commit(canonical)

      expect(composition.to_canonical_hash).not_to have_key('category')
      expect(composition.reload).to have_attributes(category_code: nil, category_value: nil)
    end
  end

  # regression pin for REST; bug for to_rm (red before #124: code_string 'event').
  it 'leaves a scaffold record on the configured default' do
    record = BmiCalculation.create!(height: 170.0)

    expect(record.rm_graph.to_rm.category.defining_code.code_string).to eq('433')
    expect(record.rm_graph.to_canonical_hash).not_to have_key('category')
  end
end

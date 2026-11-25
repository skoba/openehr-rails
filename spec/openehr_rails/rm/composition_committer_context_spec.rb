# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'

# Issue #46, proposals 1 and 2 (anlage upstream candidate 16): a canonical
# composition's context.start_time and context.setting are persisted and read back.
# other_context (proposal 3) and the CanonicalSerializer round trip stay open.
describe OpenehrRails::Rm::CompositionCommitter do
  let(:context) do
    {
      '_type' => 'EVENT_CONTEXT',
      'start_time' => { '_type' => 'DV_DATE_TIME', 'value' => '2026-03-15T09:30:00+09:00' },
      'setting' => {
        '_type' => 'DV_CODED_TEXT', 'value' => 'secondary medical care',
        'defining_code' => { 'terminology_id' => { 'value' => 'openehr' }, 'code_string' => '232' }
      }
    }
  end
  let(:canonical_hash) do
    {
      '_type' => 'COMPOSITION',
      'archetype_node_id' => 'openEHR-EHR-COMPOSITION.report-result.v1',
      'archetype_details' => {
        '_type' => 'ARCHETYPED',
        'archetype_id' => { 'value' => 'openEHR-EHR-COMPOSITION.report-result.v1' },
        'template_id' => { 'value' => 'bmi_calculation' },
        'rm_version' => '1.0.4'
      },
      'context' => context,
      'content' => []
    }
  end
  let(:from_clause) { 'FROM EHR e CONTAINS COMPOSITION c' }
  # openehr 2.6.0 can navigate EVENT_CONTEXT in an AQL path; the gemspec still
  # allows ~> 2.5, so the expectations below depend on the resolved version.
  let(:navigates_event_context) { Gem.loaded_specs['openehr'].version >= Gem::Version.new('2.6.0') }
  let(:upstream_event_context) { 'openehr < 2.6.0 cannot navigate EVENT_CONTEXT attributes in an AQL path' }
  let(:upstream_composition_uid) { 'openehr cannot navigate COMPOSITION.uid in an AQL path yet' }

  def select(path)
    OpenehrRails::Aql::Executor.execute("SELECT #{path} #{from_clause}").rows
  end

  describe 'a canonical hash carrying context' do
    # bug: red before #46 (the column stayed nil).
    it 'stores context.start_time in the context_start_time column' do
      composition = described_class.commit(canonical_hash, uid: 'ctx-1')

      expect(composition.reload.context_start_time).to eq(Time.utc(2026, 3, 15, 0, 30, 0))
    end

    # bug: red before #46 (the columns stayed nil).
    it 'stores context.setting in the setting_code / setting_value columns' do
      composition = described_class.commit(canonical_hash, uid: 'ctx-2')

      expect(composition.reload).to have_attributes(setting_code: '232', setting_value: 'secondary medical care')
    end

    # bug: red before #46 (one row holding nil). With openehr < 2.6.0 the path
    # evaluator still raises `unsupported path attribute "start_time" on a
    # ...EventContext`, so it stays pending there; openehr 2.6.0 navigates
    # EVENT_CONTEXT and the example runs green (v0.10.0 Release run 45600566175
    # resolved 2.6.0 and reported it "FIXED").
    it 'answers SELECT c/context/start_time/value' do
      pending upstream_event_context unless navigates_event_context
      described_class.commit(canonical_hash, uid: 'ctx-3')

      expect(select('c/context/start_time/value')).to eq([['2026-03-15T00:30:00Z']])
    end

    # bug: red before #46 (0 rows). Still pending: with openehr < 2.6.0 for the
    # EVENT_CONTEXT reason above; with 2.6.0 the WHERE clause itself works
    # (measured), but SELECT c/uid/value raises `unsupported path attribute
    # "uid" on a ...Composition` (an openehr-ruby question, not filed from here).
    it 'filters on c/context/start_time/value in WHERE' do
      pending(navigates_event_context ? upstream_composition_uid : upstream_event_context)
      described_class.commit(canonical_hash, uid: 'ctx-4')
      query = "SELECT c/uid/value #{from_clause} WHERE c/context/start_time/value > '2026-01-01'"

      expect(OpenehrRails::Aql::Executor.execute(query).rows.size).to eq(1)
    end

    # bug: red before #46 (to_rm.context was nil; with a kwarg, setting was always 'other').
    it 'rebuilds the stored setting through to_rm' do
      setting = described_class.commit(canonical_hash, uid: 'ctx-5').to_rm.context.setting

      expect(setting.value).to eq('secondary medical care')
      expect(setting.defining_code.code_string).to eq('232')
    end

    # regression pin: an explicit kwarg still wins over the hash.
    it 'prefers the context_start_time keyword when one is given' do
      explicit = Time.utc(2025, 1, 2, 3, 4, 5)

      composition = described_class.commit(canonical_hash, uid: 'ctx-6', context_start_time: explicit)

      expect(composition.reload.context_start_time).to eq(explicit)
    end
  end

  describe 'a canonical hash without context' do
    let(:context) { nil }

    # regression pin
    it 'leaves the context columns nil and rebuilds no EventContext' do
      composition = described_class.commit(canonical_hash.compact, uid: 'ctx-7')

      expect(composition.reload).to have_attributes(context_start_time: nil, setting_code: nil, setting_value: nil)
      expect(composition.to_rm.context).to be_nil
    end

    # regression pin: the keyword-only path (Storable) keeps the 'other' setting.
    it "keeps the 'other' setting when only the keyword supplies a start time" do
      composition = described_class.commit(canonical_hash.compact, uid: 'ctx-8',
                                                                   context_start_time: Time.utc(2025, 1, 2))

      expect(composition.to_rm.context.setting.value).to eq('other')
    end
  end
end

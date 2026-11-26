# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'

# Issue #64 (anlage upstream 25, rails half): the graph stores template_id and
# rm_version, but RmObjectBuilder did not rebuild archetype_details, so
# to_rm.archetype_details was nil and c/archetype_details/template_id/value
# could not be answered.
describe OpenehrRails::Rm::RmObjectBuilder do
  let(:archetype_details) do
    {
      '_type' => 'ARCHETYPED',
      'archetype_id' => { 'value' => 'openEHR-EHR-COMPOSITION.report-result.v1' },
      'template_id' => { 'value' => 'bmi_calculation' },
      'rm_version' => '1.0.4'
    }
  end
  let(:canonical_hash) do
    {
      '_type' => 'COMPOSITION',
      'archetype_node_id' => 'openEHR-EHR-COMPOSITION.report-result.v1',
      'archetype_details' => archetype_details,
      'content' => []
    }.compact
  end

  def commit(uid)
    OpenehrRails::Rm::CompositionCommitter.commit(canonical_hash, uid: uid)
  end

  describe 'a composition committed with archetype_details' do
    # bug: red before #64 (to_rm.archetype_details was nil).
    it 'rebuilds archetype_details with template_id, archetype_id and rm_version' do
      details = commit('ad-1').to_rm.archetype_details

      expect(details).to be_a(OpenEHR::RM::Common::Archetyped::Archetyped)
      expect(details.template_id.value).to eq('bmi_calculation')
      expect(details.archetype_id.value).to eq('openEHR-EHR-COMPOSITION.report-result.v1')
      expect(details.rm_version).to eq('1.0.4')
    end

    # bug: red before #64 (the hop found no archetype_details).
    it 'answers SELECT c/archetype_details/template_id/value' do
      commit('ad-2')

      rows = OpenehrRails::Aql::Executor.execute(
        'SELECT c/archetype_details/template_id/value FROM EHR e CONTAINS COMPOSITION c'
      ).rows

      expect(rows).to eq([['bmi_calculation']])
    end
  end

  describe 'a composition stored without template_id' do
    let(:archetype_details) { nil }

    # regression pin: it still rebuilds, and no template_id is invented.
    it 'rebuilds with no template_id' do
      rm = commit('ad-3').to_rm

      expect(rm).to be_a(OpenEHR::RM::Composition::Composition)
      expect(rm.archetype_details&.template_id).to be_nil
    end
  end

  describe 'a composition whose root node id is not an archetype id' do
    let(:canonical_hash) { { '_type' => 'COMPOSITION', 'archetype_node_id' => 'at0000', 'content' => [] } }

    # enhancement (#64): the new archetype_details step must not make such a
    # composition unreadable; it rebuilds without archetype_details.
    it 'rebuilds with archetype_details nil' do
      rm = commit('ad-4').to_rm

      expect(rm).to be_a(OpenEHR::RM::Composition::Composition)
      expect(rm.archetype_details).to be_nil
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'

# Issue #81 (anlage upstream 28): a logically deleted composition (head version
# with lifecycle_state 523) stayed in the default AQL scope and the EHR screen,
# and the delete's Contribution was recorded as an amendment.
describe OpenehrRails::Rm::CompositionCommitter do
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
      'content' => []
    }
  end
  # c/uid/value is not navigable in openehr 2.6.0, so these count rows instead.
  let(:query) { 'SELECT c/name/value FROM EHR e CONTAINS COMPOSITION c' }
  let(:composition_model) { OpenehrRails::Rm::Composition }

  def default_rows
    OpenehrRails::Aql::Executor.execute(query).rows
  end

  def rows_in(scope)
    OpenehrRails::Aql::Executor.execute(query, composition_scope: scope).rows
  end

  describe '.delete' do
    before do
      described_class.commit(canonical_hash, uid: 'keep-1')
      described_class.commit(canonical_hash, uid: 'del-1')
    end

    # bug: red before #81 (there was no delete; the REST controller's
    # re-commit left the deleted head in the default scope).
    it 'leaves the deleted composition out of the default AQL scope' do
      described_class.delete(uid: 'del-1')

      expect(default_rows.size).to eq(1)
    end

    # bug: red before #81 (change_type was amendment / 250).
    it "records the deleting version with lifecycle 523 and a 'deleted' contribution" do
      deleting = described_class.delete(uid: 'del-1').version

      expect(deleting).to have_attributes(version_tree_id: '2', lifecycle_state_code: '523')
      expect(deleting.contribution).to have_attributes(change_type_value: 'deleted', change_type_code: '523')
    end

    # enhancement: the deleted ones stay reachable on request.
    it 'still returns the deleted composition with composition_scope: Composition.latest' do
      described_class.delete(uid: 'del-1')

      expect(rows_in(composition_model.latest).size).to eq(2)
    end

    # enhancement: the EHR screen's scope.
    it 'is excluded by Composition.latest.not_deleted' do
      described_class.delete(uid: 'del-1')

      expect(composition_model.latest.not_deleted.pluck(:uid)).to eq(['keep-1'])
    end

    # regression pin: the earlier version keeps its own lifecycle and change_type.
    it 'leaves the previous version untouched' do
      described_class.delete(uid: 'del-1')
      first = OpenehrRails::Rm::Version.of_object('del-1').first

      expect(first).to have_attributes(version_tree_id: '1', lifecycle_state_code: '532')
      expect(first.contribution.change_type_value).to eq('creation')
    end

    # enhancement: deleting needs an existing head.
    it 'raises RecordNotFound for an unknown uid' do
      expect { described_class.delete(uid: 'nope') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'a version marked 523 the way REST DELETE did before #81' do
    # bug: red before #81 (the default scope looked only at latest_version).
    it 'is left out of the default AQL scope' do
      described_class.commit(canonical_hash, uid: 'old-del')
      described_class.commit(canonical_hash, uid: 'old-del')
                     .version.update!(lifecycle_state_code: OpenehrRails::Rm::Version::LIFECYCLE_DELETED)

      expect(default_rows).to be_empty
    end
  end
end

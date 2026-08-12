# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../storable_spec_model'

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

  describe '#commit (first commit)' do
    it 'creates a graph-only composition (no owner) with version 1 / creation' do
      composition = described_class.commit(canonical_hash, uid: 'uid-1')

      expect(composition).to be_persisted
      expect(composition.owner).to be_nil
      expect(composition.uid).to eq('uid-1')
      expect(composition.latest_version).to be true

      version = composition.version
      expect(version.version_tree_id).to eq('1')
      expect(version.contribution.change_type_value).to eq('creation')
    end

    it 'round-trips through CanonicalSerializer' do
      hash_with_uid = canonical_hash.merge('uid' => { '_type' => 'HIER_OBJECT_ID', 'value' => 'uid-2' })

      composition = described_class.commit(hash_with_uid, uid: 'uid-2')

      expect(composition.to_canonical_hash).to eq(hash_with_uid)
    end

    it 'materializes and links the given Ehr' do
      ehr = OpenehrRails::Rm::Ehr.create!(ehr_id: 'ehr-x')

      composition = described_class.commit(canonical_hash, uid: 'uid-3', ehr: ehr)

      expect(composition.ehr).to eq(ehr)
    end
  end

  describe '#commit (same uid again: amendment)' do
    it 'supersedes the previous head and appends version 2' do
      described_class.commit(canonical_hash, uid: 'uid-4')
      second = described_class.commit(canonical_hash, uid: 'uid-4')

      versions = OpenehrRails::Rm::Version.of_object('uid-4')
      expect(versions.map(&:version_tree_id)).to eq(%w[1 2])
      expect(versions.last.contribution.change_type_value).to eq('amendment')
      expect(OpenehrRails::Rm::Composition.where(uid: 'uid-4', latest_version: true)).to eq([second])
    end
  end

  describe '#commit with an owner (the Storable save path)' do
    it 'sets owner_type/owner_id via the polymorphic association' do
      record = nil
      begin
        OpenehrRails.rm_persistence_enabled = false # keep Storable's own auto-persist out of the way
        record = BmiCalculation.create!(height: 170.0)
      ensure
        OpenehrRails.rm_persistence_enabled = nil
      end

      composition = described_class.commit(canonical_hash, uid: 'uid-5', owner: record)

      expect(composition.owner_type).to eq('BmiCalculation')
      expect(composition.owner_id).to eq(record.id)
    end
  end
end

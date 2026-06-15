# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../storable_spec_model'

describe OpenehrRails::Rm::GraphPersister do
  describe 'create' do
    let!(:record) { BmiCalculation.create!(height: 170.0, body_weight: 65.0, ehr_id: 'patient-7') }
    let(:composition) { record.rm_graph }

    it 'persists one composition graph linked to the record' do
      expect(composition).to be_present
      expect(composition.owner).to eq(record)
      expect(composition.uid).to eq(record.uid)
      expect(composition.template_id).to eq('bmi_calculation')
    end

    it 'builds the full node graph' do
      expect(composition.content_nodes.count).to eq(2)
      expect(composition.nodes.count).to eq(10)       # 5 nodes per OBSERVATION entry
      expect(composition.data_values.count).to eq(2)  # height + body_weight
    end

    it 'materializes the Ehr from ehr_id' do
      ehr = OpenehrRails::Rm::Ehr.find_by(ehr_id: 'patient-7')
      expect(ehr).to be_present
      expect(composition.ehr).to eq(ehr)
    end

    it 'regenerates the JSON cache from the graph identically' do
      expect(composition.to_canonical_hash).to eq(record.rm_composition)
    end

    it 'records version 1 as a creation' do
      version = composition.version
      expect(version.version_tree_id).to eq('1')
      expect(version.contribution.change_type_value).to eq('creation')
      expect(version.object_version_id)
        .to eq("#{record.uid}::#{OpenehrRails.system_id}::1")
    end
  end

  describe 'update (immutable append versioning)' do
    let!(:record) { BmiCalculation.create!(height: 170.0) }

    before { record.update!(height: 168.0) }

    it 'appends version 2 as an amendment and keeps version 1 intact' do
      versions = OpenehrRails::Rm::Version.of_object(record.uid)
      expect(versions.map(&:version_tree_id)).to eq(%w[1 2])
      expect(versions.last.contribution.change_type_value).to eq('amendment')

      old_composition = versions.first.composition
      expect(old_composition.latest_version).to be(false)
      expect(old_composition.data_values.find_by(rm_type: 'DV_QUANTITY').magnitude).to eq(170.0)
    end

    it 'returns the head graph from rm_graph' do
      expect(record.rm_graph.latest_version).to be(true)
      expect(record.rm_graph.data_values.find_by(rm_type: 'DV_QUANTITY').magnitude).to eq(168.0)
    end
  end

  describe 'destroy' do
    it 'purges all versions, graphs and contributions' do
      record = BmiCalculation.create!(height: 170.0)
      record.update!(height: 168.0)
      record.destroy!

      expect(OpenehrRails::Rm::Composition.where(owner_type: 'BmiCalculation')).to be_empty
      expect(OpenehrRails::Rm::Node.count).to eq(0)
      expect(OpenehrRails::Rm::DataValue.count).to eq(0)
      expect(OpenehrRails::Rm::Version.of_object(record.uid)).to be_empty
    end
  end

  describe 'when persistence is disabled' do
    around do |example|
      OpenehrRails.rm_persistence_enabled = false
      example.run
    ensure
      OpenehrRails.rm_persistence_enabled = nil
    end

    it 'still saves the record and the JSON cache' do
      record = BmiCalculation.create!(height: 170.0)
      expect(record.rm_composition['_type']).to eq('COMPOSITION')
      expect(record.rm_graph).to be_nil
      expect(OpenehrRails::Rm::Composition.count).to eq(0)
    end
  end
end

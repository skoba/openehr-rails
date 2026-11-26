# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative 'support/storable_models'

# Issue #61 (plan docs/design/0.9.x-plan.md 3.1a, 3.2): fields under an
# embedded archetype root are written as a CLUSTER inside their entry, not as a
# second entry typed like the host.
describe OpenehrRails::Storable do
  include StorableModels

  let(:analyte_id) { 'openEHR-EHR-CLUSTER.laboratory_test_analyte.v1' }
  let(:observation_id) { 'openEHR-EHR-OBSERVATION.laboratory_test_result.v1' }

  describe 'a model whose template embeds an archetype root (lab_result_report_reduced)' do
    let(:field_map) { field_map_for('templates/lab_result_report_reduced.opt') }
    let(:model) { storable_model(:embedded_lab_results, field_map) }
    let(:record) do
      model.create!('laboratory_test_result_at0001' => 'final', 'laboratory_test_analyte_at0024' => 'Na',
                    'laboratory_test_analyte_at0001' => '140')
    end
    let(:items) { record.rm_composition['content'].first.dig('data', 'events', 0, 'data', 'items') }

    # bug: red before #61 (refused by the #60 guard; before the guard, a second OBSERVATION).
    it 'saves one entry, the host OBSERVATION' do
      expect(record.rm_composition['content'].pluck('_type', 'archetype_node_id')).to eq([['OBSERVATION', observation_id]])
    end

    # bug: red before #61.
    it 'writes the embedded root as a CLUSTER with its archetype details, holding its elements' do
      cluster = items.find { |item| item['archetype_node_id'] == analyte_id }

      expect(cluster).to include('_type' => 'CLUSTER',
                                 'archetype_details' => include('archetype_id' => { 'value' => analyte_id }))
      expect(cluster['items'].map { |item| [item['archetype_node_id'], item.dig('value', 'value')] })
        .to eq([%w[at0001 140], %w[at0024 Na]])
    end

    # bug: red before #61.
    it 'keeps the entry-owned element beside the CLUSTER' do
      expect(items.pluck('_type', 'archetype_node_id')).to eq([%w[ELEMENT at0001], ['CLUSTER', analyte_id]])
    end

    # bug: red before #61.
    it 'rebuilds the persisted graph as RM objects with the CLUSTER in place' do
      rm_items = record.rm_graph.to_rm.content.first.data.events.first.data.items
      rm_cluster = rm_items.find { |item| item.archetype_node_id == analyte_id }

      expect(rm_cluster).to be_a(OpenEHR::RM::DataStructures::ItemStructure::Representation::Cluster)
      expect(rm_cluster.items.map { |element| element.value.value }).to eq(%w[140 Na])
    end

    # bug: red before #61.
    it 'reads the values back from the composition' do
      expect(model.attributes_from_rm_composition(record.rm_composition)).to include(
        'laboratory_test_result_at0001' => 'final', 'laboratory_test_analyte_at0024' => 'Na'
      )
    end
  end

  describe 'a FIELD_MAP generated before root_chain (0.9.0 to 0.11.0)' do
    let(:field_map) do
      field_map_for('templates/lab_result_report_reduced.opt').transform_values { |field| field.except(:root_chain) }
    end
    let(:model) { storable_model(:embedded_lab_results_legacy, field_map) }

    # bug: red before #61 (refused by the #60 guard).
    it 'derives the chain from the path and saves the CLUSTER' do
      record = model.create!('laboratory_test_analyte_at0024' => 'Na')
      items = record.rm_composition['content'].sole.dig('data', 'events', 0, 'data', 'items')

      expect(items.pluck('_type', 'archetype_node_id')).to eq([['CLUSTER', analyte_id]])
    end
  end

  describe 'a FIELD_MAP generated before 0.9.0 (embedded root written [at-code])' do
    let(:field_map) do
      field_map_for('templates/lab_result_report_reduced.opt').transform_values do |field|
        field.except(:root_chain, :root_path, :instance_index)
             .merge(path: field[:path].sub("items[#{analyte_id}]", 'items[at0010]'))
      end
    end
    let(:model) { storable_model(:embedded_lab_results_pre090, field_map) }

    # regression pin: still refused, now asking for a re-scaffold.
    it 'refuses, asking for a re-scaffold' do
      expect { model.create!('laboratory_test_analyte_at0024' => 'Na') }.to raise_error(
        OpenehrRails::Storable::UnsupportedTemplateShape, /re-scaffold/
      )
    end
  end

  describe 'templates without embedded roots' do
    def filled(model)
      model.new(model::FIELD_MAP.to_h { |name, field| [name, sample_value(field)] })
    end

    # regression pin: the canonical JSON is unchanged (golden captured on master 2dfbb37).
    %w[bmi_calculation problem_list].each do |template|
      it "writes the same #{template} composition as before" do
        opt = template == 'bmi_calculation' ? 'generators/templates/bmi_calculation.opt' : 'templates/problem_list.opt'
        model = storable_model(:"pin_#{template}", field_map_for(opt))
        golden = JSON.parse(File.read(File.expand_path("../fixtures/storable/#{template}_content.json", __dir__)))

        expect(filled(model).to_rm_composition['content']).to eq(golden)
      end
    end
  end
end

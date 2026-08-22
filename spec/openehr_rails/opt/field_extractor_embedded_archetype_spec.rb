require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Opt::FieldExtractor do
  describe 'with an entry containing an embedded archetype (C_ARCHETYPE_ROOT)' do
    let(:opt_file) do
      File.expand_path('../../templates/lab_result_report_reduced.opt', __dir__)
    end
    let(:template) { OpenehrRails::Opt.parse(opt_file) }
    let(:fields) { described_class.new(template).fields }

    it 'resolves the CLUSTER-side term instead of colliding with the outer entry (at0001)' do
      field = fields.find do |candidate|
        candidate[:path].include?('/items[at0010]/items[at0001]/value')
      end

      expect(field[:label]).to eq('分析結果')
    end

    it 'resolves a CLUSTER-only term that the outer entry has no definition for (at0024)' do
      field = fields.find { |candidate| candidate[:node_id] == 'at0024' }

      expect(field[:label]).to eq('分析名')
      expect(field[:label]).not_to eq('at0024')
    end

    it 'tags the field with the embedded archetype id, not the outer entry id' do
      field = fields.find { |candidate| candidate[:node_id] == 'at0024' }

      expect(field[:archetype_id]).to eq('openEHR-EHR-CLUSTER.laboratory_test_analyte.v1')
    end
  end
end

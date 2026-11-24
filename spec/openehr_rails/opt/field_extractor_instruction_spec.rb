# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# Issue #47 (anlage upstream candidate 17). Fixture: spec/templates/jp_referral.opt
# (kind: real, jp_referral v0.2).
describe OpenehrRails::Opt::FieldExtractor do
  def extractor_for(relative_path)
    described_class.new(OpenehrRails::Opt.parse(File.expand_path(relative_path, __dir__)))
  end

  describe 'with an INSTRUCTION entry' do
    let(:extractor) { extractor_for('../../templates/jp_referral.opt') }
    let(:instruction) { extractor.entries.find { |entry| entry[:rm_type] == 'INSTRUCTION' } }
    let(:entry_path) do
      '/content[openEHR-EHR-SECTION.referral_details.v0]' \
        '/items[openEHR-EHR-INSTRUCTION.service_request.v1]'
    end

    def paths_of(node_ids)
      instruction[:fields].select { |field| node_ids.include?(field[:node_id]) }.pluck(:path)
    end

    # enhancement: red before #47 (the entry had 0 fields).
    it 'has fields for the ELEMENTs under activities/description' do
      own = instruction[:fields].select { |field| field[:archetype_id] == instruction[:archetype_id] }

      expect(own.pluck(:path)).to include(
        "#{entry_path}/activities[at0001]/description[at0009]/items[at0121]/value",
        "#{entry_path}/activities[at0001]/description[at0009]/items[at0062]/value",
        "#{entry_path}/activities[at0001]/description[at0009]/items[at0150]/value"
      )
    end

    # enhancement: red before #47.
    it 'has fields for the ELEMENTs under protocol' do
      own = instruction[:fields].select { |field| field[:archetype_id] == instruction[:archetype_id] }

      expect(own.pluck(:path)).to include(
        "#{entry_path}/protocol[at0008]/items[at0010]/value",
        "#{entry_path}/protocol[at0008]/items[at0011]/value"
      )
    end

    # enhancement: red before #47.
    it 'descends embedded CLUSTER roots under protocol, two levels deep' do
      by_archetype = instruction[:fields].group_by { |field| field[:archetype_id] }.transform_values(&:size)

      expect(by_archetype).to eq(
        'openEHR-EHR-INSTRUCTION.service_request.v1' => 5,
        'openEHR-EHR-CLUSTER.organisation.v1' => 5,
        'openEHR-EHR-CLUSTER.address.v1' => 6,
        'openEHR-EHR-CLUSTER.electronic_communication.v1' => 2,
        'openEHR-EHR-CLUSTER.person.v1' => 2
      )
    end

    # enhancement: red before #47.
    it 'keeps the fields in document order and labels them from their own archetype' do
      expect(instruction[:fields].first(4).map { |field| [field[:node_id], field[:label]] }).to eq(
        [%w[at0121 サービス名], %w[at0062 紹介目的], %w[at0150 備考], %w[at0010 依頼者オーダー識別子]]
      )
    end

    # enhancement: red before #47.
    it 'tags every INSTRUCTION field with the entry rm type' do
      expect(instruction[:fields].pluck(:entry_rm_type).uniq).to eq(['INSTRUCTION'])
    end

    # regression pin: narrative, timing and action_archetype_id are not ELEMENTs.
    it 'emits only ELEMENT value paths' do
      expect(instruction[:fields].pluck(:path)).to all(end_with('/value'))
      expect(instruction[:fields].pluck(:path).join).not_to match(/narrative|timing|action_archetype_id/)
    end

    # regression pin: the other entries of the template are untouched.
    it 'leaves the non-INSTRUCTION entries of the template as they were' do
      others = extractor.entries.reject { |entry| entry[:rm_type] == 'INSTRUCTION' }

      expect(others.map { |entry| entry[:fields].size }).to eq([3, 1, 1, 1])
    end

    it 'gives every field of the template a unique name' do
      names = extractor.fields.pluck(:name)

      expect(names.size).to eq(26)
      expect(names.uniq.size).to eq(26)
    end
  end

  describe 'with entries that carry a protocol' do
    # enhancement: red before #47 (protocol was not descended for any entry type).
    it 'extracts the protocol ELEMENT of an EVALUATION (problem_list at0070)' do
      fields = extractor_for('../../templates/problem_list.opt').fields
      field = fields.find { |candidate| candidate[:node_id] == 'at0070' }

      expect(field).to include(
        name: 'problem_diagnosis_at0070',
        path: '/content[openEHR-EHR-EVALUATION.problem_diagnosis.v1]/protocol[at0032]/items[at0070]/value',
        rm_type: 'DV_DATE_TIME'
      )
      expect(fields.size).to eq(6)
    end
  end

  describe 'with templates that have no INSTRUCTION and no protocol leaves' do
    # regression pin: listed, not assumed (#47 acceptance criterion).
    {
      '../../templates/bmi_calculation_without_uid.opt' =>
        %w[height body_weight body_mass_index body_mass_index_at0013],
      '../../generators/templates/bmi_calculation.opt' =>
        %w[height body_weight body_mass_index body_mass_index_at0013],
      '../../templates/lab_result_report_reduced.opt' =>
        %w[laboratory_test_result_at0001 laboratory_test_result_at0001_2 laboratory_test_result_at0024]
    }.each do |fixture, names|
      it "keeps the field set of #{File.basename(fixture)}" do
        expect(extractor_for(fixture).fields.pluck(:name)).to eq(names)
      end
    end
  end
end

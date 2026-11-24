# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# Issue #57 (anlage upstream candidate 22; plan docs/design/0.9.0-plan.md 4.2).
describe OpenehrRails::Opt::FieldExtractor do
  def fields_of(relative_path)
    described_class.new(OpenehrRails::Opt.parse(File.expand_path(relative_path, __dir__))).fields
  end

  describe 'fields under an embedded archetype root (lab_result_report_reduced)' do
    let(:fields) { fields_of('../../templates/lab_result_report_reduced.opt') }
    let(:entry_path) { '/content[openEHR-EHR-OBSERVATION.laboratory_test_result.v1]' }
    let(:root_path) do
      "#{entry_path}/data[at0002]/events[at0003]/data[at0004]/items[openEHR-EHR-CLUSTER.laboratory_test_analyte.v1]"
    end
    let(:analyte) { fields.find { |field| field[:node_id] == 'at0024' } }

    # enhancement: red before #57 (the root was written `items[at0010]`).
    it 'writes the embedded root segment as [archetype_id]' do
      expect(analyte[:path]).to eq("#{root_path}/items[at0024]/value")
    end

    # enhancement: red before #57 (laboratory_test_result_at0001_2 / _at0024).
    it 'names them after their own archetype concept and at-code' do
      expect(fields.pluck(:name)).to eq(
        %w[laboratory_test_result_at0001 laboratory_test_analyte_at0001 laboratory_test_analyte_at0024]
      )
    end

    # enhancement: red before #57 (no such key).
    it 'carries the path of the nearest embedded root as root_path' do
      expect(analyte[:root_path]).to eq(root_path)
    end

    # enhancement: red before #57 (no such key).
    it 'gives a field owned by the entry itself the entry path as root_path' do
      own = fields.find { |field| field[:archetype_id] == 'openEHR-EHR-OBSERVATION.laboratory_test_result.v1' }

      expect(own[:root_path]).to eq(entry_path)
    end
  end

  describe 'nested and repeated embedded roots (jp_referral)' do
    let(:fields) { fields_of('../../templates/jp_referral.opt') }
    let(:protocol) do
      '/content[openEHR-EHR-SECTION.referral_details.v0]' \
        '/items[openEHR-EHR-INSTRUCTION.service_request.v1]/protocol[at0008]'
    end
    let(:organisation) { 'items[openEHR-EHR-CLUSTER.organisation.v1]' }

    # enhancement: red before #57.
    it 'writes every embedded root on the way, two levels deep' do
      field = fields.find { |candidate| candidate[:name] == 'address_at0001' }

      expect(field[:path]).to eq("#{protocol}/#{organisation}/items[openEHR-EHR-CLUSTER.address.v1]/items[at0001]/value")
      expect(field[:root_path]).to eq("#{protocol}/#{organisation}/items[openEHR-EHR-CLUSTER.address.v1]")
    end

    # enhancement: red before #57.
    it 'names every field as planned, numbering repeats in document order' do
      expect(fields.pluck(:name)).to eq(
        %w[
          service_request_at0121 service_request_at0062 service_request_at0150 service_request_at0010
          organisation_at0001
          address_at0001 address_at0002 address_at0003 address_at0004 address_at0005 address_at0018
          electronic_communication_at0001 electronic_communication_at0002
          person_at0001
          service_request_at0011
          organisation_at0001_2
          organisation_at0001_3 organisation_at0003 organisation_at0004
          person_at0001_2
          problem_diagnosis_at0002 problem_diagnosis_at0077 problem_diagnosis_at0073
          story clinical_synopsis clinical_synopsis_2
        ]
      )
    end

    # enhancement: red before #57 (no such key).
    it 'numbers fields sharing a path with instance_index, in document order' do
      shared = fields.group_by { |field| field[:path] }.select { |_path, group| group.size > 1 }

      expect(shared.transform_values { |group| group.map { |field| [field[:name], field[:instance_index]] } }).to eq(
        "#{protocol}/#{organisation}/items[at0001]/value" => [['organisation_at0001', 0], ['organisation_at0001_2', 1]],
        '/content[openEHR-EHR-SECTION.referral_details.v0]/items[openEHR-EHR-EVALUATION.clinical_synopsis.v1]' \
        '/data[at0001]/items[at0002]/value' => [['clinical_synopsis', 0], ['clinical_synopsis_2', 1]]
      )
    end

    # enhancement: red before #57. The pin the ruling asks for: (path, instance_index) is a key.
    it 'makes (path, instance_index) unique across the template' do
      keys = fields.map { |field| [field[:path], field[:instance_index]] }

      expect(keys).to all(satisfy { |(_path, index)| index.is_a?(Integer) })
      expect(keys.uniq.size).to eq(26)
    end
  end

  describe 'units of a DV_QUANTITY (bmi_calculation)' do
    let(:bmi) do
      fields_of('../../generators/templates/bmi_calculation.opt').find { |field| field[:name] == 'body_mass_index' }
    end

    # enhancement: red before #57 (no such key).
    it 'lists every unit in OPT order as units_list' do
      expect(bmi[:units_list]).to eq(['kg/m2', '[lb_av]/[in_i]2'])
    end

    # regression pin
    it 'keeps units as the first unit' do
      expect(bmi[:units]).to eq('kg/m2')
    end
  end

  describe 'templates without embedded roots' do
    # regression pin: paths and names are untouched.
    it 'keeps bmi_calculation paths and names' do
      fields = fields_of('../../generators/templates/bmi_calculation.opt')

      expect(fields.pluck(:name)).to eq(%w[height body_weight body_mass_index body_mass_index_at0013])
      expect(fields.first[:path]).to eq(
        '/content[openEHR-EHR-OBSERVATION.height.v2]/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value'
      )
      expect(fields.pluck(:instance_index)).to eq([0, 0, 0, 0])
    end

    # regression pin
    it 'keeps problem_list names' do
      expect(fields_of('../../templates/problem_list.opt').pluck(:name)).to eq(
        %w[problem_diagnosis_at0002 problem_diagnosis_at0077 problem_diagnosis_at0003
           problem_diagnosis_at0030 problem_diagnosis_at0073 problem_diagnosis_at0070]
      )
    end
  end
end

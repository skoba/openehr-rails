# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# Issue #61 (plan docs/design/0.9.x-plan.md 3.1a): instance_index numbers fields
# per path, so it cannot tell which instance of a repeated root a field belongs
# to. root_chain names every archetype root from the entry down, each with the
# document-order ordinal of its root path.
describe OpenehrRails::Opt::FieldExtractor do
  def fields_of(relative_path)
    described_class.new(OpenehrRails::Opt.parse(File.expand_path(relative_path, __dir__))).fields
  end

  def field(name)
    fields.find { |candidate| candidate[:name] == name }
  end

  describe 'one embedded root (lab_result_report_reduced)' do
    let(:fields) { fields_of('../../templates/lab_result_report_reduced.opt') }
    let(:entry_path) { '/content[openEHR-EHR-OBSERVATION.laboratory_test_result.v1]' }

    # enhancement: red before #61 (no such key).
    it 'gives an entry-owned field a one-element chain' do
      expect(field('laboratory_test_result_at0001')[:root_chain]).to eq([[entry_path, 0]])
    end

    # enhancement: red before #61.
    it 'gives a field under the embedded root the entry, then the root' do
      expect(field('laboratory_test_analyte_at0024')[:root_chain]).to eq(
        [[entry_path, 0], [field('laboratory_test_analyte_at0024')[:root_path], 0]]
      )
    end
  end

  describe 'repeated and nested roots (jp_referral)' do
    let(:fields) { fields_of('../../templates/jp_referral.opt') }
    let(:entry_path) do
      '/content[openEHR-EHR-SECTION.referral_details.v0]/items[openEHR-EHR-INSTRUCTION.service_request.v1]'
    end
    let(:organisation) { "#{entry_path}/protocol[at0008]/items[openEHR-EHR-CLUSTER.organisation.v1]" }

    # enhancement: red before #61.
    it 'puts the first organisation\'s address under organisation 0' do
      expect(field('address_at0001')[:root_chain]).to eq(
        [[entry_path, 0], [organisation, 0], ["#{organisation}/items[openEHR-EHR-CLUSTER.address.v1]", 0]]
      )
    end

    # enhancement: red before #61 (instance_index alone put it under organisation 0).
    it 'puts the organisation nested in the second organisation under organisation 1' do
      expect(field('organisation_at0001_3')[:root_chain]).to eq(
        [[entry_path, 0], [organisation, 1], ["#{organisation}/items[openEHR-EHR-CLUSTER.organisation.v1]", 0]]
      )
    end

    # enhancement: red before #61.
    it 'numbers a repeated entry by its own ordinal' do
      synopsis = '/content[openEHR-EHR-SECTION.referral_details.v0]/items[openEHR-EHR-EVALUATION.clinical_synopsis.v1]'

      expect([field('clinical_synopsis'), field('clinical_synopsis_2')].pluck(:root_chain)).to eq(
        [[[synopsis, 0]], [[synopsis, 1]]]
      )
    end
  end
end

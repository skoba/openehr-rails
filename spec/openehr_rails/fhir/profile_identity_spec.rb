# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# Issue #55 (anlage upstream candidate 23): StructureDefinition id / url / name /
# title are qualified by the template, and both generators take them from one place.
describe OpenehrRails::Fhir::ProfileIdentity do
  def template_for(relative_path)
    OpenehrRails::Opt.parse(File.expand_path(relative_path, __dir__))
  end

  let(:problem_list) { template_for('../../templates/problem_list.opt') }
  let(:jp_referral) { template_for('../../templates/jp_referral.opt') }

  describe '.for' do
    subject(:identity) { described_class.for('bmi_calculation', 'openEHR-EHR-OBSERVATION.height.v2') }

    # enhancement: red before #55 (no such module).
    it 'qualifies id, url, name and title by the template' do
      expect(identity).to eq(
        id: 'openehr-bmi-calculation-observation-height-v2',
        url: 'urn:openehr:bmi_calculation:openEHR-EHR-OBSERVATION.height.v2',
        name: 'OpenehrBmiCalculationObservationHeightV2',
        title: 'openEHR Height (bmi_calculation: openEHR-EHR-OBSERVATION.height.v2)'
      )
    end

    # enhancement: red before #55.
    it 'keeps a long id within 64 FHIR id characters, deterministically' do
      template_id = 'a_very_long_operational_template_identifier_for_testing_limits'
      archetype_id = 'openEHR-EHR-EVALUATION.problem_diagnosis.v1'
      id = described_class.for(template_id, archetype_id)[:id]

      expect(id.length).to be <= 64
      expect(id).to match(/\A[A-Za-z0-9\-.]+\z/)
      expect(id).to match(/-[0-9a-f]{8}\z/)
      expect(described_class.for(template_id, archetype_id)[:id]).to eq(id)
      expect(described_class.for("#{template_id}_2", archetype_id)[:id]).not_to eq(id)
    end

    # enhancement: red before #55.
    it 'gives a FHIR-valid name' do
      expect(identity[:name]).to match(/\A[A-Z][A-Za-z0-9_]*\z/)
    end
  end

  describe 'two templates sharing an archetype (problem_list, jp_referral)' do
    let(:archetype_id) { 'openEHR-EHR-EVALUATION.problem_diagnosis.v1' }

    # bug: red before #55 (both were openehr-evaluation-problem-diagnosis-v1).
    it 'gives them different JSON profile ids, urls and names' do
      profiles = [problem_list, jp_referral].map do |template|
        OpenehrRails::Fhir::ProfileGenerator.new(template).profiles.find { |p| p[:url].end_with?(archetype_id) }
      end

      expect(profiles.pluck(:id)).to eq(
        %w[openehr-problemlist-evaluation-problem-diagnosis-v1 openehr-jp-referral-evaluation-problem-diagnosis-v1]
      )
      expect(profiles.pluck(:url).uniq.size).to eq(2)
      expect(profiles.pluck(:name).uniq.size).to eq(2)
    end

    # bug: red before #55.
    it 'gives them different FSH profile ids' do
      ids = [problem_list, jp_referral].map { |template| OpenehrRails::Fhir::FshGenerator.new(template).to_fsh_files.keys }

      expect(ids.flatten).to include('openehr-problemlist-evaluation-problem-diagnosis-v1',
                                     'openehr-jp-referral-evaluation-problem-diagnosis-v1')
      expect(ids.flatten.uniq.size).to eq(ids.flatten.size)
    end
  end

  # enhancement: red before #55 (JSON name was the bare concept, FSH used the id).
  it 'makes the JSON id / name and the FSH Id: / Profile: lines agree for every profile' do
    [problem_list, jp_referral, template_for('../../generators/templates/bmi_calculation.opt')].each do |template|
      json = OpenehrRails::Fhir::ProfileGenerator.new(template).profiles
      fsh = OpenehrRails::Fhir::FshGenerator.new(template).to_fsh_files

      expect(fsh.keys).to eq(json.map { |p| p[:id] })
      json.each do |profile|
        expect(fsh.fetch(profile[:id])).to start_with(
          "Profile: #{profile[:name]}\nParent: #{profile[:type]}\nId: #{profile[:id]}\nTitle: \"#{profile[:title]}\"\n"
        ).or include("\nProfile: #{profile[:name]}\nParent: #{profile[:type]}\nId: #{profile[:id]}\nTitle: \"#{profile[:title]}\"\n")
      end
    end
  end
end

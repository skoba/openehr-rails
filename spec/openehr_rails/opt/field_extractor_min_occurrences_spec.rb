# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# Issue #58 (anlage upstream candidate 20): the ELEMENT's own lower bound is exposed
# as min_occurrences; required keeps meaning "entry mandatory and element mandatory".
describe OpenehrRails::Opt::FieldExtractor do
  def fields_of(relative_path)
    described_class.new(OpenehrRails::Opt.parse(File.expand_path(relative_path, __dir__))).fields
  end

  describe 'problem_list (a 1..1 element inside a 0..1 entry)' do
    let(:fields) { fields_of('../../templates/problem_list.opt') }
    let(:diagnosis_name) { fields.find { |field| field[:node_id] == 'at0002' } }

    # enhancement: red before #58 (no such key).
    it 'reports the mandatory element with min_occurrences 1' do
      expect(diagnosis_name[:min_occurrences]).to eq(1)
    end

    # enhancement: red before #58 (no such key).
    it 'reports the optional elements with min_occurrences 0' do
      others = fields.reject { |field| field[:node_id] == 'at0002' }

      expect(others.pluck(:min_occurrences)).to eq([0, 0, 0, 0, 0])
    end

    # regression pin: required is still false under an optional entry.
    it 'leaves required as it was' do
      expect(fields.pluck(:required)).to eq([false] * 6)
    end
  end

  # enhancement: red before #58 (no such key).
  it 'gives every field of every fixture an Integer min_occurrences' do
    fixtures = %w[../../templates/jp_referral.opt ../../templates/lab_result_report_reduced.opt
                  ../../generators/templates/bmi_calculation.opt]
    values = fixtures.flat_map { |fixture| fields_of(fixture).pluck(:min_occurrences) }

    expect(values).to all(be_an(Integer))
  end
end

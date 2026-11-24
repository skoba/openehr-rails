# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# Issue #47: once an INSTRUCTION has leaves, it is skipped as "leaves with no
# mapping row" (#35 will add the rows), not as a 0-leaf entry. Fixture:
# spec/templates/jp_referral.opt (kind: real).
describe OpenehrRails::Fhir, 'generators on a template holding an INSTRUCTION' do
  let(:template) { OpenehrRails::Opt.parse(File.expand_path('../../templates/jp_referral.opt', __dir__)) }
  let(:instruction_id) { 'openEHR-EHR-INSTRUCTION.service_request.v1' }

  {
    OpenehrRails::Fhir::ProfileGenerator => ->(generator) { generator.profiles.pluck(:id) },
    OpenehrRails::Fhir::FshGenerator => ->(generator) { generator.to_fsh_files.keys }
  }.each do |generator_class, emitted_ids|
    describe generator_class do
      let(:generator) { generator_class.new(template) }
      let(:skipped_instruction) do
        emitted_ids.call(generator)
        generator.skipped.find { |error| error.archetype_id == instruction_id }
      end

      # enhancement: red before #47 (leaf_count 0, "no leaves").
      it 'reports the INSTRUCTION with its real leaf count and the missing mapping row' do
        expect(skipped_instruction.leaf_count).to eq(20)
        expect(skipped_instruction.message).to include('ServiceRequest', 'ENTRY_ELEMENT_MAPS')
        expect(skipped_instruction.message).not_to include('no leaves')
      end

      # regression pin: no ServiceRequest profile is emitted without a mapping row.
      it 'emits no profile for it' do
        expect(emitted_ids.call(generator)).to eq(
          %w[openehr-evaluation-problem-diagnosis-v1 openehr-observation-story-v1]
        )
      end
    end
  end
end

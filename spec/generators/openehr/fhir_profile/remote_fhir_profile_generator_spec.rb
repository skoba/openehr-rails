# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'generators/openehr/fhir_profile/fhir_profile_generator'

module Openehr
  module Generators
    describe FhirProfileGenerator, 'with a remote OPT URL' do
      destination File.expand_path('../../../../tmp', __dir__)

      let(:opt_body) do
        File.read(File.expand_path('../../templates/bmi_calculation.opt', __dir__))
      end
      let(:opt_url) { 'https://example.com/templates/bmi_calculation.opt' }

      before do
        prepare_destination
        stub_request(:get, opt_url).to_return(status: 200, body: opt_body)
        run_generator [opt_url]
      end

      it 'fetches the OPT and writes profiles as usual' do
        expect(file('app/fhir/profiles/openehr-observation-height-v2.json'))
          .to contain('"resourceType": "StructureDefinition"')
      end
    end

    describe FhirProfileGenerator, 'with a remote OPT URL that cannot be fetched' do
      destination File.expand_path('../../../../tmp', __dir__)

      before do
        prepare_destination
        stub_request(:get, 'https://example.com/missing.opt').to_return(status: 404)
      end

      it 'raises a clear error instead of a raw HTTP exception' do
        expect { run_generator ['https://example.com/missing.opt'] }
          .to raise_error(Thor::Error, /Could not fetch OPT/)
      end
    end
  end
end

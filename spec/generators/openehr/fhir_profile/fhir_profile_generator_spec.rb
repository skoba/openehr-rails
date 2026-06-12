# frozen_string_literal: true

require 'spec_helper'
require 'generators/openehr/fhir_profile/fhir_profile_generator'

module Openehr
  module Generators
    describe FhirProfileGenerator do
      destination File.expand_path('../../../../tmp', __dir__)

      let(:opt_file) do
        File.expand_path('../../templates/bmi_calculation.opt', __dir__)
      end

      before do
        prepare_destination
        run_generator [opt_file]
      end

      it 'writes a StructureDefinition JSON per entry' do
        expect(file('app/fhir/profiles/openehr-observation-height-v2.json'))
          .to contain('"resourceType": "StructureDefinition"')
        expect(file('app/fhir/profiles/openehr-observation-height-v2.json'))
          .to contain('"fhirVersion": "5.0.0"')
        expect(file('app/fhir/profiles/openehr-observation-body-weight-v2.json')).to exist
        expect(file('app/fhir/profiles/openehr-observation-body-mass-index-v2.json')).to exist
      end
    end
  end
end

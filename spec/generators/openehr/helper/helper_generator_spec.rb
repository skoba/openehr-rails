require 'spec_helper'
require 'generators/openehr/helper/helper_generator'

module Openehr
  module Generators
    describe HelperGenerator do
      destination File.expand_path('../../../../../tmp', __FILE__)

      before do
        prepare_destination
        run_generator %w(spec/generators/templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl)
      end

      context 'helper generation' do
        subject { file('app/helpers/open_ehr_ehr_observation_blood_pressure_v1_helper.rb') }

        it { should exist }
        it { should contain /module OpenEhrEhrObservationBloodPressureV1Helper/ }
      end
    end
  end
end

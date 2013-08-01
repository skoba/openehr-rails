require 'spec_helper'
require 'generators/openehr/helper/helper_generator'
require 'generator_helper'

module Openehr
  module Generators
    describe HelperGenerator do
      destination File.expand_path('../../../../../tmp', __FILE__)

      before(:each) do
        prepare_destination
        run_generator [archetype]
      end

      context 'helper generation' do
        subject { file('app/helpers/open_ehr_ehr_observation_blood_pressure_v1_helper.rb') }

        it { should exist }
        it { should contain /module OpenEhrEhrObservationBloodPressureV1Helper/ }
      end
    end
  end
end

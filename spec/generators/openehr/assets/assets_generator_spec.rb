require 'spec_helper'
require 'generators/openehr/assets/assets_generator'

module Openehr
  module Generators
    describe AssetsGenerator do
      destination File.expand_path('../../../../../tmp', __FILE__)

      before do
        prepare_destination
        run_generator %w(spec/generators/templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl)
      end

      context 'scaffold.css' do
        subject { file('app/assets/stylesheets/scaffold.css') }

        it { should exist }
        it { should contain /body {/}
      end

      context 'generate scss file' do
        subject { file('app/assets/stylesheets/open_ehr_ehr_observation_blood_pressure_v1.css.scss') }

        it { should exist }
      end

      context 'generate coffeescript' do
        subject { file('app/assets/javascripts/open_ehr_ehr_observation_blood_pressure_v1.js.coffee') }

        it { should exist }
      end
    end
  end
end

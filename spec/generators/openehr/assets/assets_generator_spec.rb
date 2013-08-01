require 'spec_helper'
require 'generators/openehr/assets/assets_generator'
require 'openehr/am'
require 'openehr/rm'
require 'openehr/parser'
require 'generator_helper'
module Openehr
  module Generators
    describe AssetsGenerator do
      destination File.expand_path('../../../../../tmp', __FILE__)

      before(:each) do
        prepare_destination
        run_generator [archetype]
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

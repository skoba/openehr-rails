require 'spec_helper'
require 'generators/openehr/scaffold/scaffold_generator'

module OpenEHR
  module Rails
    module Generators
      describe ScaffoldGenerator do
        destination File.expand_path('../../../../../tmp', __FILE__)

        before do
          prepare_destination
          run_generator %w(spec/generators/templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl)
        end

        describe 'invoke index.html.erb template engine' do
          subject { file('app/views/open_ehr_ehr_observation.blood_pressure.v1/index.html.erb') }

          it { should exist }
        end
      end
    end
  end
end

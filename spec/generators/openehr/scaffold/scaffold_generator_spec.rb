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

        describe 'invoke show.html.erb template engine' do
          subject { file('app/views/open_ehr_ehr_observation.blood_pressure.v1/show.html.erb') }

          it { should exist }
        end

        describe 'invoke edit.html.erb template engine' do
          subject { file('app/views/open_ehr_ehr_observation.blood_pressure.v1/edit.html.erb')}

          it { should exist }
        end

        describe 'invoke _form.html.erb template engine' do
          subject { file('app/views/open_ehr_ehr_observation.blood_pressure.v1/_form.html.erb')}

          it { should exist }
        end
      end
    end
  end
end

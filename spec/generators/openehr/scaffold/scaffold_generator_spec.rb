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
          it { should contain /\<h1\>Listing \<%= t\("\.at0000"\) %\>\<\/h1\>/ }
          it { should contain /\<th\>\<%= t\("\.at0004"\) %\>\<\/th\>/ }
          it { should contain /\<th\>\<%= t\("\.at0005"\) %\>\<\/th\>/ }
          it { should_not contain /\<th\>\<%= t\("\.at0006"\) %\>\<\/th\>/ }
          it { should contain /\<td\>\<%= open_ehr_ehr_observation_blood_pressure_v1\.at0004 %\>\<\/td\>/ }
          it { should contain /link_to \<%= t\("\.at0000"\) %\>/}
        end

        describe 'invoke show.html.erb template engine' do
          subject { file('app/views/open_ehr_ehr_observation.blood_pressure.v1/show.html.erb') }

          it { should exist }
          it { should contain /Observation/ }
          it { should contain /t\(\"\.at0000\"\)/ }
          it { should contain /Data/ }
          it { should contain /Protocol/ }
        end

        describe 'invoke edit.html.erb template engine' do
          subject { file('app/views/open_ehr_ehr_observation.blood_pressure.v1/edit.html.erb') }

          it { should exist }
          it { should contain /Editing \<%= t\(\"\.at0000\"\) /}
        end

        describe 'invoke _form.html.erb template engine' do
          subject { file('app/views/open_ehr_ehr_observation.blood_pressure.v1/_form.html.erb')}

          it { should exist }
          it { should contain // }
          
        end

        describe 'invoke routing generator' do
          subject { file('config/routes.rb')}

          it { should contain /scope "\/:locale" do/ }
          it { should contain /resources :open_ehr_ehr_observation.blood_pressure.v1/}
        end

        describe 'application controller modifier' do
          subject { file('app/controllers/application_controller.rb')}

          it { should contain /before_action :set_locale/ }
          it { should contain /def set_locale/ }
          it { should contain /I18n\.locale = params\[:locale\] \|\| I18n.default_locale/ }
          it { should contain /end$/ }
        end
      end
    end
  end
end

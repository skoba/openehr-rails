require 'spec_helper'
require 'generators/openehr/scaffold/scaffold_generator'
require 'generator_helper'

module Openehr
  module Generators
    describe ScaffoldGenerator do
      destination File.expand_path('../../../../../tmp', __FILE__)

      before(:each) do
        prepare_destination
        run_generator [archetype]
      end

      context 'invoke index.html.erb template engine' do
        subject { file('app/views/open_ehr_ehr_observation_blood_pressure_v1/index.html.erb') }

        it { should exist }
        it { should contain /\<h1\>Listing \<%= t\("\.at0000"\) %\>\<\/h1\>/ }
        it { should contain /\<th\>\<%= t\("\.at0004"\) %\>\<\/th\>/ }
        it { should contain /\<th\>\<%= t\("\.at0005"\) %\>\<\/th\>/ }
        it { should_not contain /\<th\>\<%= t\("\.at0006"\) %\>\<\/th\>/ }
        it { should contain /\<td\>\<%= open_ehr_ehr_observation_blood_pressure_v1\.at0004 %\>\<\/td\>/ }
#        it { should contain /link_to \<%= t\("\.at0000"\) %\>/}
      end

      context 'invoke show.html.erb template engine' do
        subject { file('app/views/open_ehr_ehr_observation_blood_pressure_v1/show.html.erb') }

        it { should exist }
        it { should contain /Observation/ }
        it { should contain /t\(\"\.at0000\"\)/ }
        it { should contain /Data/ }
        it { should contain /Protocol/ }
      end

      context 'invoke edit.html.erb template engine' do
        subject { file('app/views/open_ehr_ehr_observation_blood_pressure_v1/edit.html.erb') }

        it { should exist }
        it { should contain /Editing \<%= t\(\"\.at0000\"\) /}
      end

      context 'invoke _form.html.erb template engine' do
        subject { file('app/views/open_ehr_ehr_observation_blood_pressure_v1/_form.html.erb')}

        it { should exist }
        it { should contain // }
      end

      context 'invoke routing generator' do
        subject { file('config/routes.rb')}

        it { should contain /scope "\/:locale" do/ }
        it { should contain /resources :open_ehr_ehr_observation.blood_pressure.v1/}
      end

      context 'invoke assets generator' do
        subject { file('app/assets/stylesheets/scaffold.css') }

        it { should exist }
      end

      context 'i18n generator' do
        subject { file('config/initializers/i18n.rb') }

        it { should exist}
      end
      
      context 'invoke helper generator' do
        subject { file('app/helpers/open_ehr_ehr_observation_blood_pressure_v1_helper.rb')}

        it { should exist }
      end

      describe 'controller generator' do
        subject { file('app/controllers/open_ehr_ehr_observation_blood_pressure_v1_controller.rb') }

        it { should exist }
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

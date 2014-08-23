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

      context 'invoke migration generator' do
        context 'generate rm migration' do
          subject { file('db/migrate/create_rms.rb') }
          
          it { is_expected.to be_a_migration}
        end

        context 'generate archetype migration' do
          subject { file('db/migrate/create_archetypes.rb') }

          it { is_expected.to be_a_migration }
        end
      end

      
      context 'generate rm model' do
        subject { file('app/models/open_ehr_ehr_observation_blood_pressure_v1.rb') }

        it { is_expected.to exist}
      end

      context 'invoke index.html.erb template engine' do
        subject { file('app/views/open_ehr_ehr_observation_blood_pressure_v1/index.html.erb') }

        it { is_expected.to exist }
        it { is_expected.to contain '<h1>Listing <%= t(".at0000") %></h1>' }
        it { is_expected.to contain '<th><%= t(".at0004") %></th>' }
        it { is_expected.to contain '<th><%= t(".at0005") %></th>' }
        it { is_expected.not_to contain '<th><%= t(".at0006") %></th>' }
        it { is_expected.to contain '<td><%= open_ehr_ehr_observation_blood_pressure_v1.at0004 %></td>' }
        it { is_expected.to contain "<%= link_to 'Show', open_ehr_ehr_observation_blood_pressure_v1_path(id: open_ehr_ehr_observation_blood_pressure_v1.id) %>"}
        it { is_expected.to contain "<%= link_to 'Edit', edit_open_ehr_ehr_observation_blood_pressure_v1_path(id: open_ehr_ehr_observation_blood_pressure_v1.id) %>" }
        it { is_expected.to contain "<%= link_to 'Destroy', open_ehr_ehr_observation_blood_pressure_v1_path(id: open_ehr_ehr_observation_blood_pressure_v1.id), method: :delete, data: { confirm: 'Are you sure?' } %>"}
      end

      context 'invoke show.html.erb template engine' do
        subject { file('app/views/open_ehr_ehr_observation_blood_pressure_v1/show.html.erb') }

        it { is_expected.to contain 'Data' }
        it { is_expected.to contain "<strong><%= t('.at0005') %></strong>: " }
        it { is_expected.to contain '<%= @open_ehr_ehr_observation_blood_pressure_v1.at0005 %>mm[Hg]<br/>' }
        it { is_expected.to contain 'Protocol' }
        it { is_expected.to contain "<strong><%= t('.at0013') %></strong>: <%= @open_ehr_ehr_observation_blood_pressure_v1.at0013 %>"}
      end

      context 'invoke edit.html.erb template engine' do
        subject { file('app/views/open_ehr_ehr_observation_blood_pressure_v1/edit.html.erb') }

        it { is_expected.to exist }
        it { is_expected.to contain "Editing <%= t('.at0000')"}
      end

      context 'invoke new.html.erb template engine' do
        subject { file('app/views/open_ehr_ehr_observation_blood_pressure_v1/new.html.erb')}

        it { is_expected.to exist}
        it { is_expected.to contain /New \<%= t\(\".at0000\"\) %\>/ }
      end

      context 'invoke _form.html.erb template engine' do
        subject { file('app/views/open_ehr_ehr_observation_blood_pressure_v1/_form.html.erb')}

        it { is_expected.to exist }
        it { is_expected.to contain "f.select :at0013, t('.at0015') => 'at0015', t('.at0016') => 'at0016'"}
        it { is_expected.to contain "<%= t('.at0006') %></strong>: <%= f.text_field :at0006 %>" }
      end

      context 'invoke routing generator' do
        subject { file('config/routes.rb')}

        it { is_expected.to contain 'resources :open_ehr_ehr_observation_blood_pressure_v1'}
      end

      context 'Insert inflection setting' do
        subject { file('config/initializers/inflections.rb') }
        
        it { is_expected.to contain 'inflect.uncountable %w( open_ehr_ehr_observation_blood_pressure_v1 )' }
      end

      context 'invoke assets generator' do
        subject { file('app/assets/stylesheets/scaffold.css') }

        it { is_expected.to exist }
      end

      context 'i18n generator' do
        subject { file('config/initializers/i18n.rb') }

        it { is_expected.to exist }
      end
      
      context 'add locale switcher to application.html.erb' do
        subject { file('app/views/layouts/application.html.erb') }

        it { is_expected.to exist }
        it { is_expected.to contain /\<%= select_tag 'locale',/ }
        it { is_expected.to contain /options_for_select\(LANGUAGES, I18n\.locale.to_s\),/ }
      end

      context 'layout.css.scss' do
        subject { file('app/assets/stylesheets/layout.css.scss') }

        it { is_expected.to exist }
        it { is_expected.to contain /\.locale {/ }
      end

      context 'invoke helper generator' do
        subject { file('app/helpers/open_ehr_ehr_observation_blood_pressure_v1_helper.rb')}

        it { is_expected.to exist }
      end

      describe 'controller generator' do
        subject { file('app/controllers/open_ehr_ehr_observation_blood_pressure_v1_controller.rb') }

        it { is_expected.to exist }
      end

      describe 'application controller modifier' do
        subject { file('app/controllers/application_controller.rb') }

        it { is_expected.to contain /before_action :set_locale/ }
        it { is_expected.to contain /def set_locale/ }
        it { is_expected.to contain /I18n\.locale = params\[:locale\] \|\| session\[:locale\] \|\| I18n\.default_locale/ }
        it { is_expected.to contain /end$/ }
      end
    end
  end
end

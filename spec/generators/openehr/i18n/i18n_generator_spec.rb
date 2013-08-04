# -*- coding: utf-8 -*-
require 'spec_helper'
require 'generators/openehr/i18n/i18n_generator'
require 'generator_helper'

module Openehr
  module Generators
    describe I18nGenerator do
      destination File.expand_path '../../../../../tmp/', __FILE__

      before(:each) do
        prepare_destination
        run_generator [archetype]
      end

      describe 'File generation' do
        describe 'i18n.rb generation' do
          subject { file('config/initializers/i18n.rb') }

          it { should exist }
          it { should contain /I18n\.default_locale = :en/ }
          it { should contain /LANGUAGES/ }
          it { should contain /\['English', 'en'\],/ }
          it { should contain /\['Japanese', 'ja'\]/ }
          it { should contain /\['Dutch', 'nl'\],/ }
        end

        describe 'en.yml generation' do
          subject { file('config/locales/en.yml') }

          it { should exist }
          it { should contain /en:/ }
          it { should contain /layouts:/ }
          it { should contain /application:/ }
          it { should contain /open_ehr_ehr_observation_blood_pressure_v1/ }
          it { should contain /index: &ontology/ }
          it { should contain /at0000: "Blood Pressure"/ }
          it { should contain /at0001: "history"/ }
          it { should contain /new: \*ontology/ }
          it { should contain /form: \*ontology/ }
          it { should contain /show: \*ontology/ }
          it { should contain /edit: \*ontology/ }
        end

        describe 'ja.yml generation' do
          subject { file('config/locales/ja.yml')}

          it { should exist }
          it { should contain /ja:/ }
        end

        describe 'nl.yml generation' do
          subject { file('config/locales/nl.yml') }

          it { should exist }
          it { should contain /nl:/ }
        end
      end
    end
  end
end

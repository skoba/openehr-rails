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

          it { is_expected.to exist }
          it { is_expected.to contain /I18n\.default_locale = :en/ }
          it { is_expected.to contain /LANGUAGES/ }
          it { is_expected.to contain /\['English', 'en'\],/ }
          it { is_expected.to contain /\['Japanese', 'ja'\]/ }
          it { is_expected.to contain /\['Dutch', 'nl'\],/ }
        end

        describe 'en.yml generation' do
          subject { file('config/locales/en.yml') }

          it { is_expected.to exist }
          it { is_expected.to contain /en:/ }
          it { is_expected.to contain /layouts:/ }
          it { is_expected.to contain /application:/ }
          it { is_expected.to contain /open_ehr_ehr_observation_blood_pressure_v1/ }
          it { is_expected.to contain /index: &ontology/ }
          it { is_expected.to contain /at0000: "Blood Pressure"/ }
          it { is_expected.to contain /at0001: "history"/ }
          it { is_expected.to contain /new: \*ontology/ }
          it { is_expected.to contain /form: \*ontology/ }
          it { is_expected.to contain /show: \*ontology/ }
          it { is_expected.to contain /edit: \*ontology/ }
        end

        describe 'ja.yml generation' do
          subject { file('config/locales/ja.yml')}

          it { is_expected.to exist }
          it { is_expected.to contain /ja:/ }
        end

        describe 'nl.yml generation' do
          subject { file('config/locales/nl.yml') }

          it { is_expected.to exist }
          it { is_expected.to contain /nl:/ }
        end
      end
    end
  end
end

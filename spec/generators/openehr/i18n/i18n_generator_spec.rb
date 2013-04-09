# -*- coding: utf-8 -*-
require 'spec_helper'
require 'generators/openehr/i18n/i18n_generator'

module OpenEHR
  module Rails
    module Generators
      describe I18nGenerator do
        destination File.expand_path(destination_root)

        before do
          prepare_destination
          run_generator %w(spec/generators/templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl)
        end

        describe 'File generation' do
          describe 'i18n.rb generation' do
            subject { file('config/initializers/i18n.rb') }

            it { should exist }
            it { should contain /I18n\.default_locale = :en/ }
            it { should contain /LANGUAGES/ }
            it { should contain /\['English', 'en'\]/ }
            it { should contain /\['Japanese', 'ja'\]/ }
            it { should contain /\['Dutch', 'nl'\]/ }
          end

          describe 'en.yml generation' do
            subject { file('config/locales/en.yml') }

            it { should exist }
            it { should contain /en:/}
            it { should contain /at0000: "Blood Pressure"/ }
          end

          describe 'ja.yml generation' do
            subject { file('config/locales/ja.yml')}

            it { should exist }
            it { should contain /ja:/ }
          end
        end
      end
    end
  end
end

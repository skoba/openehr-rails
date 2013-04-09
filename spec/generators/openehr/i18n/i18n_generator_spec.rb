require 'spec_helper'
require 'generators/openehr/i18n/i18n_generator'

module OpenEHR
  module Rails
    module Generators
      describe I18nGenerator do
        destination File.expand_path(destination_root)

        before { prepare_destination }

        context 'create i18n file' do
          before do
            run_generator %w(spec/generators/templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl)
          end

          subject { file('config/initializers/i18n.rb') }

          it { should exist }
          it { should contain /I18n\.default_locale = :en/ }
          it { should contain /LANGUAGES/ }
          it { should contain /\['English', 'en'\]/ }
          it { should contain /\['Japanese', 'ja'\]/ }
          it { should contain /\['Dutch', 'nl'\]/ }
        end
      end
    end
  end
end

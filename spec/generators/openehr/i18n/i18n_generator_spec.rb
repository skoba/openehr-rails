require 'spec_helper'
require 'generators/openehr/i18n/i18n_generator'

module OpenEHR
  module Rails
    module Generators
      describe I18nGenerator do
        destination File.expand_path(destination_root)

        before { prepare_destination }

        describe 'config/initializers/i18n.rb' do
          before do
            run_generator %w(../../templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl)
          end

          subject { file('config/initializers/i18n.rb') }

          it { should exist }
        end
      end
    end
  end
end

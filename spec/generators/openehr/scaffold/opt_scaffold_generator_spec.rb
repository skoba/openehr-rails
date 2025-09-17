require 'spec_helper'
require 'generators/openehr/scaffold/scaffold_generator'
require 'generator_helper'

module Openehr
  module Generators
    describe ScaffoldGenerator, 'with OPT file' do
      destination File.expand_path('../../../../../tmp', __FILE__)

      let(:opt_file) { File.expand_path('../../templates/bmi_calculation.opt', __FILE__) }

      before(:each) do
        prepare_destination
        # Configure ActiveRecord to avoid connection errors in generator tests
        allow(ActiveRecord::Base).to receive(:establish_connection)
        allow(ActiveRecord::Base).to receive(:connection)
        run_generator [opt_file]
      end

      context 'when generating views from OPT file' do
        let(:controller_path) { 'bmi_calculation' }

        context 'generate index.html.erb' do
          subject { file("app/views/#{controller_path}/index.html.erb") }

          it { is_expected.to exist }
          it { is_expected.to contain '<h1>Listing BMI Calculation</h1>' }
          it { is_expected.to contain '<th>Height</th>' }
          it { is_expected.to contain '<th>Weight</th>' }
        end

        context 'generate show.html.erb' do
          subject { file("app/views/#{controller_path}/show.html.erb") }

          it { is_expected.to exist }
          it { is_expected.to contain '<strong>Height</strong>:' }
          it { is_expected.to contain '<strong>Weight</strong>:' }
        end

        context 'generate _form.html.erb' do
          subject { file("app/views/#{controller_path}/_form.html.erb") }

          it { is_expected.to exist }
          it { is_expected.to contain 'f.number_field :height' }
          it { is_expected.to contain 'f.number_field :weight' }
        end
      end
    end
  end
end
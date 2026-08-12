# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'generators/openehr/scaffold/scaffold_generator'

module Openehr
  module Generators
    describe ScaffoldGenerator, 'with a remote OPT URL' do
      destination File.expand_path('../../../../../tmp', __FILE__)

      let(:opt_body) do
        File.read(File.expand_path('../../../templates/bmi_calculation.opt', __FILE__))
      end
      let(:opt_url) { 'https://example.com/templates/bmi_calculation.opt' }

      before(:each) do
        prepare_destination
        FileUtils.mkdir_p(File.join(destination_root, 'config'))
        File.write(File.join(destination_root, 'config/routes.rb'),
                   "Rails.application.routes.draw do\nend\n")
        stub_request(:get, opt_url).to_return(status: 200, body: opt_body)
        run_generator [opt_url]
      end

      it 'fetches the OPT and scaffolds the model as usual' do
        expect(file('app/models/bmi_calculation.rb')).to contain 'class BmiCalculation < ApplicationRecord'
      end

      it 'copies the fetched content into app/templates/operational, named after the template_id' do
        expect(file('app/templates/operational/bmi_calculation.opt')).to contain(opt_body)
      end
    end

    describe ScaffoldGenerator, 'with a remote OPT URL that cannot be fetched' do
      destination File.expand_path('../../../../../tmp', __FILE__)

      before(:each) do
        prepare_destination
        FileUtils.mkdir_p(File.join(destination_root, 'config'))
        File.write(File.join(destination_root, 'config/routes.rb'),
                   "Rails.application.routes.draw do\nend\n")
        stub_request(:get, 'https://example.com/missing.opt').to_return(status: 404)
      end

      it 'raises a clear error instead of a raw HTTP exception' do
        expect { run_generator ['https://example.com/missing.opt'] }
          .to raise_error(Thor::Error, /Could not fetch OPT/)
      end
    end
  end
end

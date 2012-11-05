require 'spec_helper'
require 'generators/openehr/controller/controller_generator'

describe OpenEHR::Rails::Generators::ControllerGenerator do

  destination File.expand_path("../../../../../tmp", __FILE__)

  before { prepare_destination }

  describe 'controller spec' do
    subject{ file('app/controllers/open_ehr_ehr_observation.v1_controller.rb') }

    before do
      run_generator %w(openEHR-EHR-OBSERVATION.v1)
    end

    describe 'controller spec' do
      it { should exist }
    end

    it 'retrieve archetype from CKM with --remote option' do
    
    end

    it 'parse archetype if app/archetype with --local option'
  end
end

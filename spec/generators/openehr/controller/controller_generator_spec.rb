require 'spec_helper'
require 'generators/openehr/controller/controller_generator'

describe OpenEHR::Rails::Generators::ControllerGenerator do

  destination File.expand_path("../../../../../tmp", __FILE__)

  before { prepare_destination }

  describe 'controller spec' do
    describe 'default action' do
      before do
        run_generator %w(openEHR-EHR-OBSERVATION.v1)
      end

      subject{ file('app/controllers/open_ehr_ehr_observation.v1_controller.rb') }
      it { should exist }
    end

    describe 'generate controller on local archetype library' do
      before do
        run_generator %w(openEHR-EHR-OBSERVATION.v1 --local)
      end

      # it ' app/archetype with --local option' do
        
      # end
    end


    describe 'retrieve archetype from remote repository' do
      it 'retrieve archetype from CKM with --remote option'
    end
  end
end

require 'spec_helper'
require 'generators/openehr/controller/controller_generator'

describe Openehr::Generators::ControllerGenerator do

  destination File.expand_path("../../../../../tmp", __FILE__)

  before { prepare_destination }

  before do
    prepare_destination
    run_generator %w(spec/generators/templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl)
  end

  subject { file('app/controllers/open_ehr_ehr_observation_blood_pressure_v1_controller.rb') }

  it { should exist }

end

require 'spec_helper'
require 'generators/openehr/controller/controller_generator'

describe OpenEHR::Rails::Generators::ControllerGenerator do

  destination File.expand_path("../../../../../tmp", __FILE__)

  before { prepare_destination }
end

require 'spec_helper'
require 'generators/openehr/install/install_generator'

describe OpenEHR::Generators::InstallGenerator do
  destination File.expand_path('../../../../tmp', __FILE__)

  before { prepare_destination }

  it 'creates app/archetype directory' do
    run_generator
    file('app/archetype').should exist
  end

  it 'creates initializer' do 
    run_generator
    file('config/initializer')
  end
end

require 'spec_helper'
require 'generators/openehr/install/install_generator'

describe OpenEHR::Rails::Generators::InstallGenerator do
  destination File.expand_path('../../../../../tmp', __FILE__)

  before do 
    prepare_destination
  end

  it 'makes app/archetypes directory' do
    run_generator
    file('app/archetypes').should exist
  end
end

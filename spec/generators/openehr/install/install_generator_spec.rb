require 'spec_helper'
require 'generators/openehr/install/install_generator'

describe Openehr::Generators::InstallGenerator do
  destination File.expand_path('../../../../../tmp', __FILE__)

  before(:each) do 
    prepare_destination
    run_generator
  end

  it 'makes app/archetypes directory' do
    expect(file('app/archetypes')).to exist
  end
end

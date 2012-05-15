require 'spec_helper'
require 'generators/openehr/install/install_generator'

describe OpenEHR::Generators::InstallGenerator do
  destination File.expand_path('../../../../../tmp', __FILE__)

  before do 
    prepare_destination
    run_generator
  end

  subject{ file('app/archetypes') }

  it { should exist }
end

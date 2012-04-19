require 'spec_helper'
require 'generators/archetype/install/install_generator'

describe Archtype::Generator::InstallGenerator do
  destination File.expand_path('../../../../tmp', __FILE__)
  before { prepare_destination }

  it 'should create app/archetype directory' do
    run_generator
    file('app/archetype').should exist
  end
end

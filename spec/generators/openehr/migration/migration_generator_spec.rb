require 'spec_helper'
require 'generators/openehr/migration/migration_generator'

describe Openehr::Generators::MigrationGenerator do
  destination File.expand_path(destination_root)

  before(:all) do
    prepare_destination
    run_generator
  end

  describe 'default rm db migration' do

    # subject {file('db/migration/20121127020800_create_archetype_db')}

    # it { should exist }
  end
end

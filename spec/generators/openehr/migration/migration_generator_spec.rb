require 'spec_helper'
require 'generators/openehr/migration/migration_generator'

describe OpenEHR::Rails::Generators::MigrationGenerator do
  destination File.expand_path(destination_root)

  before { prepare_destination }

  describe 'default rm db migration' do
    before { run_generator }

    subject {file('db/migration/20121127020800_create_archetype_db')}

    it { should exist }
  end
end

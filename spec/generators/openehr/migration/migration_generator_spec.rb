require 'spec_helper'
require 'generators/openehr/migration/migration_generator'

module Openehr
  module Generators
    describe MigrationGenerator do
      destination File.expand_path('../../../../../tmp', __FILE__)

      before(:each) do
        prepare_destination
        run_generator
      end

      context 'default archetype db migration' do
        subject { file('db/migrate/create_archetypes.rb') }

        it { should be_a_migration }
      end

      context 'default rm db migration' do
        subject { file('db/migrate/create_rms.rb') }

        it { should be_a_migration }
      end
    end
  end
end

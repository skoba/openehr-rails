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
        subject { file('db/migration/create_archetypes.rb') }

        it { should be_a_migration }
      end

      context 'default rm db migration' do

        it 'is a migration' do
          file('db/migration/create_rms.db').should be_a_migration
        end
        # subject {  }

        # it { should be_a_migration }
      end
    end
  end
end

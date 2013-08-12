require 'generators/openehr'
require 'rails/generators/active_record'
require 'rails/generators/migration'
require 'rails/generators/base'

module Openehr
  module Generators
    class MigrationGenerator < ::Rails::Generators::Base 
      include ::Rails::Generators::Migration

      source_root File.expand_path("../templates", __FILE__)

      def make_directory
        empty_directory 'db/migrate'
      end

      def copy_archetype_migration
        migration_template 'archetypes.rb', 'db/migrate/create_archetypes.rb'
      end

      def copy_rm_migration
        migration_template 'rms.rb', 'db/migrate/create_rms.rb'
      end

      private
      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end
    end
  end
end

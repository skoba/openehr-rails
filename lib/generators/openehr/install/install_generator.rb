# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module Openehr
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      desc <<~DESC
        Description:
          Sets up the openEHR environment: the OpenehrTemplate registry model,
          its migration, an initializer, and the template storage directory.
      DESC

      source_root File.expand_path('templates', __dir__)

      def create_template_registry_model
        template 'models/openehr_template.rb', 'app/models/openehr_template.rb'
      end

      def copy_migration
        migration_template 'migrations/create_openehr_templates.rb',
                           'db/migrate/create_openehr_templates.rb'
      end

      def create_initializer
        template 'initializers/openehr.rb', 'config/initializers/openehr.rb'
      end

      def create_template_directory
        empty_directory 'app/templates/operational'
      end

      def mount_admin_engine
        route "mount OpenehrRails::Engine => '/openehr'"
      end

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::STRING.to_f}]"
      end
    end
  end
end

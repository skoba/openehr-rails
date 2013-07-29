require 'generators/openehr'
require 'rails/generators/active_record'

module Openehr
  module Generators
    class MigrationGenerator < ::ActiveRecord::Generators::Base
      argument :attributes
      source_root File.expand_path("./templates", __FILE__)
      
      def copy_archetype_migration
          
      end
    end
  end
end

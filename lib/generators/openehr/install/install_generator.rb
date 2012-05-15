module OpenEHR
  module Generators
    class InstallGenerator < ::Rails::Generators::Base

      desc <<DESC
Description: 
  setup openEHR environment with archetype directory.
DESC
      
      def self.source_root
        @source_root ||= File.dirname(__FILE__)
      end

      def create_archetype_directory
        empty_directory 'app/archetypes'
      end
    end
  end
end

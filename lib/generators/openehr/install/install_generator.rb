module OpenEHR
  module Rails
    module Generators
      class InstallGenerator < ::Rails::Generators::Base
        
        desc <<DESC
Description: 
  setup openEHR environment with archetype directory.
DESC
      
        def create_archetype_directory
          empty_directory 'app/archetypes'
        end
      end
    end
  end
end


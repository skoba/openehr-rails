require 'generators/openehr'

module OpenEHR
  module Rails
    module Generators
      class ControllerGenerator < Base
        argument :actions, :type => :array, :default => [], :bannar => 'action action'
        desc <<DESC
generate controler from template and archetype
DESC

        def create_controller
          template 'controller.rb', File.join('app/controllers', class_path, "#{file_name}_controller.rb")
        end
      end
    end
  end
end

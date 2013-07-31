require 'generators/openehr'

module Openehr
  module Generators
    class ControllerGenerator < ArchetypedBase
      source_root File.expand_path("../templates", __FILE__)
      argument :actions, :type => :array, :default => [], :bannar => 'action action'
      desc <<DESC
generate controler from template and archetype
DESC

      def create_controller
        template 'controller.rb', File.join('app/controllers', "#{controller_name}_controller.rb")
      end
    end
  end
end

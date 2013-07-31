require 'generators/openehr'

module Openehr
  module Generators
    class HelperGenerator < ArchetypedBase
      source_root File.expand_path("../templates", __FILE__)

      def create_helper_directory
        empty_directory 'app/helpers'
      end

      def copy_helper_file
        template 'helper.rb', File.join('app/helpers', "#{model_name}_helper.rb")
      end
    end
  end
end

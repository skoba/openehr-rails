require 'generators/openehr'

module Openehr
  module Generators
    class ModelGenerator < ArchetypedBase
      source_root File.expand_path("../templates", __FILE__)
      desc "generate archetype model and migragion file"

      def create_empty_directory
        empty_directory File.join('app/models')
      end

      def generate_rm
        template 'rm.rb', File.join('app/models', 'rm.rb')
      end

      def generate_archetype
        template 'archetype.rb', File.join('app/models', 'archetype.rb')
      end
    end
  end
end


require 'openehr/am'
require 'openehr/rm'
require 'openehr/parser'
require 'openehr/ckm_client'

module Openehr
  module Generators
    class ArchetypedBase < ::Rails::Generators::Base
      def initialize(args, *options)
        if args[0].class == OpenEHR::AM::Archetype::Archetype
          @archetype = args[0]
        else
          @adl_file = args[0]
        end
        super
      end

      protected
      def archetype
        @archetype ||= OpenEHR::Parser::ADLParser.new(@adl_file).parse
      end
      
      def archetype_path
        'app/archetypes'
      end

      def archetype_file
        @adl_file
      end

      def archetype_name
        archetype.archetype_id.value
      end

      def controller_name
        archetype_name.underscore.tr '.', '_'
      end

      def controller_file_path
        controller_name
      end

      def model_name
        controller_name
      end

      def concept
        archetype.concept
      end

      def model_class_name
        model_name.camelize
      end

      def controller_class_name
        model_class_name + 'Controller'
      end
    end
  end
end

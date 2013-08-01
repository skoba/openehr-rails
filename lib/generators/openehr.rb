require 'openehr/am'
require 'openehr/rm'
require 'openehr/parser'
require 'openehr/ckm_client'

module Openehr
  module Generators
    class ArchetypedBase < ::Rails::Generators::Base
      argument :archetype

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
        @archetype ||= OpenEHR::Parser::ADLParser.new(archetype_file).parse
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
        archetype.archetype_id.value.underscore.tr '.', '_'
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

      def data_tree
        archetype.definition.attributes.each do |attribute|
          return attribute if attribute.rm_attribute_name == "data"
        end
      end

      def index_data(tree = data_tree)
        data = []
        if tree.has_children?
          data = tree.children.inject([]) do |values, child|
            if child.respond_to? :attributes
              child.attributes.each do |attribute|
                if attribute.rm_attribute_name == 'value'
                  values << child.node_id unless child.node_id.nil?
                end
                if attribute.has_children?
                  values.concat index_data(attribute)
                end
              end
            end
            values
          end
        end
        data
      end

      def show_data(tree = archetype.definition)
      end
    end
  end
end

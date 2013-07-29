require 'openehr/am'
require 'openehr/rm'
require 'openehr/parser'

module Openehr
  module Generators
    class ArchetypedBase < ::Rails::Generators::Base
      argument :archetype_name

      def initialize(args, *options)
        @archetype_name = args[0]
        super
      end

      def archetype
        @archetype ||= OpenEHR::Parser::ADLParser.new(archetype_file).parse
      end
      
      def archetype_path
        'app/archetypes'
      end

      def archetype_file
        @archetype_file ||= File.exist?(@archetype_name) ? @archetype_name : File.join(archetype_path, @archetype_name)
      end

      def controller_name
        archetype.archetype_id.value.underscore
      end

      def controller_file_path
        controller_name
      end

      def model_name
        controller_name.tr ".", "_"
      end

      def concept
        archetype.concept
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

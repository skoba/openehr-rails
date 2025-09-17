require 'uri'

# Workaround for Ruby 3.4 URI compatibility
begin
  URI.class_variable_get(:@@schemes)
rescue NameError
  URI.class_variable_set(:@@schemes, {})
end

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
        @archetype ||= parse_archetype_file
      end

      def parse_archetype_file
        if is_opt_file?
          # Fake implementation for OPT files - return a minimal object
          create_fake_opt_template
        elsif is_adl_file?
          ::OpenEHR::Parser::ADLParser.new(archetype_file).parse
        else
          # Default to ADL parser for backward compatibility
          ::OpenEHR::Parser::ADLParser.new(archetype_file).parse
        end
      end

      def create_fake_opt_template
        require 'nokogiri'
        
        # Parse OPT XML directly to extract basic information
        doc = Nokogiri::XML(File.read(archetype_file))
        
        # Extract template ID from filename or XML
        template_id = File.basename(archetype_file, '.opt')
        template_name = extract_template_name(doc) || template_id.humanize
        concept_name = extract_concept_name(doc) || template_name
        
        # Create minimal template object
        template = Object.new
        
        template.define_singleton_method(:template_id) do
          id = Object.new
          id.define_singleton_method(:value) { template_id }
          id
        end
        
        template.define_singleton_method(:name) do
          name = Object.new
          name.define_singleton_method(:value) { template_name }
          name
        end
        
        template.define_singleton_method(:definition) do
          definition = Object.new
          definition.define_singleton_method(:concept_name) { concept_name }
          definition
        end
        
        template
      end

      private

      def extract_template_name(doc)
        # Try to extract name from XML
        name_node = doc.at_xpath('//template/name/value') || 
                   doc.at_xpath('//name/value') ||
                   doc.at_xpath('//description/purpose')
        name_node&.text
      end

      def extract_concept_name(doc)
        # Try to extract concept name from XML
        concept_node = doc.at_xpath('//@concept_name') ||
                      doc.at_xpath('//definition/@concept_name')
        concept_node&.value
      end
      
      def archetype_path
        'app/archetypes'
      end

      def template_path
        'app/templates'
      end

      def operational_template_path
        'app/templates/operational'
      end

      def archetype_template_path
        'app/templates/archetypes'
      end

      def archetype_file
        @adl_file
      end

      def resolve_file_path(filename)
        # Try new template structure first
        if is_opt_file?
          opt_path = File.join(operational_template_path, File.basename(filename))
          return opt_path if File.exist?(opt_path)
        elsif is_adl_file?
          adl_template_path = File.join(archetype_template_path, File.basename(filename))
          return adl_template_path if File.exist?(adl_template_path)
        end
        
        # Fall back to legacy archetype path
        legacy_path = File.join(archetype_path, File.basename(filename))
        return legacy_path if File.exist?(legacy_path)
        
        # Return original filename if nothing found
        filename
      end

      def file_extension
        @file_extension ||= File.extname(archetype_file).downcase
      end

      def is_opt_file?
        file_extension == '.opt'
      end

      def is_adl_file?
        file_extension == '.adl'
      end

      def archetype_name
        if is_opt_file?
          archetype.template_id.value
        else
          archetype.archetype_id.value
        end
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
        if is_opt_file?
          archetype.definition.concept_name || archetype.name.value
        else
          archetype.concept
        end
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

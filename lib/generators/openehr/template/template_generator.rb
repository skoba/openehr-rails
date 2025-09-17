module Openehr
  module Generators
    class TemplateGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)
      
      argument :template_file, type: :string, 
               desc: "Path to OPT/Web Template file (.opt or .json)"
      
      class_option :format, type: :string, default: 'opt',
                   desc: "Template format: opt or web_template"
      
      def parse_template
        @template = case options[:format]
                   when 'opt'
                     parse_opt_template
                   when 'web_template'
                     parse_web_template
                   else
                     raise "Unknown template format: #{options[:format]}"
                   end
        
        extract_template_structure
      end
      
      def generate_form_model
        template 'form_model.rb.erb', 
                "app/models/forms/#{file_name}_form.rb"
      end
      
      def generate_controller
        template 'template_controller.rb.erb',
                "app/controllers/#{file_name.pluralize}_controller.rb"
      end
      
      def generate_views
        create_form_views
        create_display_views
        create_search_views
      end
      
      def generate_validation_rules
        template 'validator.rb.erb',
                "app/validators/#{file_name}_validator.rb"
      end
      
      def generate_value_sets
        # terminology bindingsの生成
        template 'value_sets.yml.erb',
                "config/openehr/value_sets/#{file_name}.yml"
      end
      
      def add_routes
        route "resources :#{file_name.pluralize} do"
        route "  collection do"
        route "    post :search"
        route "    get :export"
        route "  end"
        route "end"
      end
      
      private
      
      def parse_opt_template
        parser = OpenEHR::Parser::OPTParser.new(File.read(template_file))
        parser.parse
      end
      
      def parse_web_template
        json = JSON.parse(File.read(template_file))
        OpenEHR::Template::WebTemplate.from_json(json)
      end
      
      def extract_template_structure
        @sections = []
        @fields = []
        @constraints = []
        @terminology_bindings = []
        
        @template.definition.traverse do |node|
          case node.rm_type_name
          when /SECTION/
            @sections << extract_section(node)
          when /OBSERVATION/, /EVALUATION/, /ACTION/, /INSTRUCTION/
            extract_entry_fields(node)
          end
        end
      end
      
      def extract_entry_fields(entry_node)
        entry_node.traverse do |node|
          if node.is_leaf? && node.has_constraint?
            @fields << {
              path: node.path,
              name: node.name,
              rm_type: node.rm_type_name,
              constraints: node.constraints,
              occurrences: node.occurrences,
              terminology_binding: extract_terminology_binding(node)
            }
          end
        end
      end
    end
  end
end
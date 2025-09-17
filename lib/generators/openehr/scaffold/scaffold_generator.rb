# openehr-rails/lib/generators/openehr/scaffold/scaffold_generator.rb
module Openehr
  module Generators
    class ScaffoldGenerator < ::Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)
      
      argument :opt_file, type: :string, desc: "Path to OPT file"
      
      class_option :namespace, type: :string, default: nil,
                   desc: "Namespace for generated files (e.g., 'ehr')"
      
      def parse_opt_file
        @opt = parse_operational_template
        @template_id = @opt.template_id
        @model_name = generate_model_name_from_template_id
        @human_name = @opt.concept || @model_name.humanize
        
        say "Generating scaffold for template: #{@template_id}"
        say "Model name: #{@model_name.camelize}"
        say "Controller name: #{@model_name.camelize.pluralize}Controller"
      end
      
      def check_dependencies
        unless Template.exists?(template_id: @template_id)
          Template.create!(
            template_id: @template_id,
            name: @human_name,
            definition: @opt.to_json,
            archetype_id: @opt.definition.archetype_id,
            version: extract_version(@template_id)
          )
          say "Created Template record: #{@template_id}"
        end
      end
      
      def generate_model
        template 'model.rb.erb', 
                "app/models/#{model_file_path}.rb"
      end
      
      def generate_form_model
        template 'form_model.rb.erb',
                "app/models/forms/#{@model_name}_form.rb"
      end
      
      def generate_controller
        template 'controller.rb.erb',
                "app/controllers/#{controller_file_path}.rb"
      end
      
      def generate_views
        %w[index show new edit _form _search].each do |view|
          template "views/#{view}.html.erb",
                  "app/views/#{view_path}/#{view}.html.erb"
        end
        
        generate_field_partials
      end
      
      def generate_serializer
        template 'serializer.rb.erb',
                "app/serializers/#{@model_name}_serializer.rb"
      end
      
      def generate_value_sets
        if @opt.terminology_bindings.any?
          template 'value_sets.yml.erb',
                  "config/openehr/value_sets/#{@template_id}.yml"
        end
      end
      
      def generate_routes
        route_string = if options[:namespace]
          <<~ROUTE
            namespace :#{options[:namespace]} do
              resources :#{@model_name.pluralize} do
                collection do
                  get :search
                  post :aql_query
                end
              end
            end
          ROUTE
        else
          <<~ROUTE
            resources :#{@model_name.pluralize} do
              collection do
                get :search
                post :aql_query
              end
            end
          ROUTE
        end
        
        route route_string
      end
      
      def generate_tests
        template 'rspec/model_spec.rb.erb',
                "spec/models/#{@model_name}_spec.rb"
        template 'rspec/controller_spec.rb.erb',
                "spec/controllers/#{@model_name.pluralize}_controller_spec.rb"
        template 'rspec/request_spec.rb.erb',
                "spec/requests/#{@model_name.pluralize}_spec.rb"
      end
      
      private
      
      def parse_operational_template
        opt_content = File.read(opt_file)
        OpenEHR::Parser::OPTParser.new(opt_content).parse
      rescue => e
        say "Error parsing OPT file: #{e.message}", :red
        raise
      end
      
      def generate_model_name_from_template_id
        # Template ID例: 
        # "openEHR-EHR-COMPOSITION.vital_signs_encounter.v1"
        # "IDCR-MedicationStatement.v0"
        # "EHRN-HEARTRISK.v0"
        
        # 変換ルール:
        # 1. openEHR- prefix を除去
        # 2. EHR- を除去
        # 3. COMPOSITION/OBSERVATION等を除去
        # 4. バージョン番号を除去
        # 5. Rails規約に従った名前に変換
        
        name = @template_id.dup
        
        # プレフィックスの除去
        name.gsub!(/^openEHR-EHR-/, '')
        name.gsub!(/^openEHR-/, '')
        name.gsub!(/^IDCR-/, '')
        name.gsub!(/^EHRN-/, '')
        
        # RMタイプの除去
        %w[COMPOSITION OBSERVATION EVALUATION ACTION INSTRUCTION ADMIN_ENTRY].each do |rm_type|
          name.gsub!(/^#{rm_type}\./, '')
        end
        
        # バージョン番号の除去
        name.gsub!(/\.v\d+(\.\d+)?$/, '')
        
        # アンダースコア化
        name.downcase.gsub(/[.-]/, '_')
      end
      
      def extract_version(template_id)
        if template_id =~ /\.v(\d+(?:\.\d+)?)$/
          $1
        else
          "0.1"
        end
      end
      
      def model_file_path
        if options[:namespace]
          "#{options[:namespace]}/#{@model_name}.rb"
        else
          "#{@model_name}.rb"
        end
      end
      
      def controller_file_path
        if options[:namespace]
          "#{options[:namespace]}/#{@model_name.pluralize}_controller.rb"
        else
          "#{@model_name.pluralize}_controller.rb"
        end
      end
      
      def view_path
        if options[:namespace]
          "#{options[:namespace]}/#{@model_name.pluralize}"
        else
          @model_name.pluralize
        end
      end
      
      def generate_field_partials
        @opt.field_types.each do |rm_type|
          partial_name = "_#{rm_type.underscore}.html.erb"
          unless File.exist?("app/views/openehr/fields/#{partial_name}")
            template "views/fields/#{rm_type.underscore}.html.erb",
                    "app/views/openehr/fields/#{partial_name}"
          end
        end
      end
    end
  end
end
# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'
require 'openehr_rails'

module Openehr
  module Generators
    # Generates a full Rails resource (model, migration, controller, views,
    # routes, i18n locale, request spec) from an openEHR Operational
    # Template (.opt). The generated model stores typed columns plus the
    # canonical RM composition JSON (see OpenehrRails::Storable).
    class ScaffoldGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      argument :opt_file, type: :string, desc: 'Path to OPT file'

      class_option :namespace, type: :string, default: nil,
                               desc: "Namespace for controller/views/routes (e.g. 'ehr')"

      def parse_opt_file
        @opt = OpenehrRails::Opt.parse(opt_file)
        @template_id = @opt.template_id.value
        @model_name = model_name_from_template_id(@template_id)
        @human_name = (@opt.concept || @model_name).humanize

        extractor = OpenehrRails::Opt::FieldExtractor.new(@opt)
        @entries = extractor.entries
        @fields = extractor.fields

        say "Generating scaffold for template: #{@template_id}"
        say "Model name: #{class_name}"
        warn_on_repeating_entries
      end

      def copy_opt_into_app
        create_file "app/templates/operational/#{opt_basename}",
                    File.read(opt_file)
      end

      def register_template_in_seeds
        seeds = File.join(destination_root, 'db/seeds.rb')
        if File.exist?(seeds)
          append_to_file 'db/seeds.rb', seed_line
        else
          create_file 'db/seeds.rb', seed_line
        end
      end

      def generate_model
        template 'model.rb.erb', "app/models/#{@model_name}.rb"
      end

      def generate_migration
        migration_template 'migration.rb.erb',
                           "db/migrate/create_#{table_name}.rb"
      end

      def generate_controller
        template 'controller.rb.erb',
                 "app/controllers/#{controller_file_path}_controller.rb"
      end

      def generate_views
        %w[index show new edit _form].each do |view|
          template "views/#{view}.html.erb",
                   "app/views/#{view_path}/#{view}.html.erb"
        end
      end

      def generate_locale
        template 'locale.yml.erb',
                 "config/locales/#{@model_name}.#{locale_code}.yml"
      end

      def generate_routes
        if options[:namespace]
          route <<~ROUTE
            namespace :#{options[:namespace]} do
              resources :#{plural_name}
            end
          ROUTE
        else
          route "resources :#{plural_name}"
        end
      end

      def generate_request_spec
        template 'request_spec.rb.erb', "spec/requests/#{plural_name}_spec.rb"
      end

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      private

      attr_reader :fields, :entries

      def migration_version
        "[#{ActiveRecord::VERSION::STRING.to_f}]"
      end

      def model_name_from_template_id(template_id)
        name = template_id.dup
        name.gsub!(/^openEHR-EHR-/, '')
        name.gsub!(/^openEHR-/, '')
        name.gsub!(/^IDCR-/, '')
        name.gsub!(/^EHRN-/, '')
        %w[COMPOSITION OBSERVATION EVALUATION ACTION INSTRUCTION ADMIN_ENTRY].each do |rm_type|
          name.gsub!(/^#{rm_type}\./, '')
        end
        name.gsub!(/\.v\d+(\.\d+)?$/, '')
        name.downcase.gsub(/[.\s-]/, '_')
      end

      def class_name
        @model_name.camelize
      end

      def plural_name
        @model_name.pluralize
      end
      alias table_name plural_name

      def controller_file_path
        [options[:namespace], plural_name].compact.join('/')
      end

      def view_path
        controller_file_path
      end

      def controller_class_name
        [options[:namespace]&.camelize, "#{plural_name.camelize}Controller"].compact.join('::')
      end

      def route_helper_prefix
        [options[:namespace], @model_name].compact.join('_')
      end

      def opt_basename
        File.basename(opt_file)
      end

      def seed_line
        "OpenehrTemplate.from_opt_file(Rails.root.join('app/templates/operational/#{opt_basename}')) " \
          "if defined?(OpenehrTemplate)\n"
      end

      def locale_code
        @opt.original_language&.code_string || 'en'
      end

      def warn_on_repeating_entries
        entries.each do |entry|
          occurrences = entry[:occurrences]
          next unless occurrences.respond_to?(:upper) && occurrences.upper.to_i > 1

          say "Warning: entry #{entry[:archetype_id]} repeats (occurrences > 1); " \
              'only single occurrences are scaffolded.', :yellow
        end
      end

      # --- code fragments used by the ERB templates ---

      def field_map_source
        lines = fields.map do |field|
          "    '#{field[:name]}' => #{field.except(:name).inspect}"
        end
        "{\n#{lines.join(",\n")}\n  }.freeze"
      end

      def validation_lines
        fields.filter_map do |field|
          validations = []
          validations << 'presence: true' if field[:required]
          if field[:rm_type] == 'DV_QUANTITY' && field[:magnitude_range]
            lower, upper = field[:magnitude_range]
            bounds = []
            bounds << "greater_than_or_equal_to: #{lower}" if lower
            bounds << "less_than_or_equal_to: #{upper}" if upper
            validations << "numericality: { #{bounds.join(', ')} }, allow_nil: true" if bounds.any?
          end
          next if validations.empty?

          "  validates :#{field[:name]}, #{validations.join(', ')}"
        end
      end

      def migration_column_lines
        fields.flat_map do |field|
          lines = ["      t.#{field[:column_type]} :#{field[:name]}"]
          if field[:rm_type] == 'DV_QUANTITY'
            default = field[:units] ? ", default: '#{field[:units]}'" : ''
            lines << "      t.string :#{field[:name]}_units#{default}"
          end
          lines
        end
      end

      def permitted_params
        fields.map { |field| ":#{field[:name]}" }.join(', ')
      end

      def form_input_for(field)
        name = field[:name]
        case field[:rm_type]
        when 'DV_QUANTITY'
          input = "<%= f.number_field :#{name}, step: :any#{range_options(field)} %>"
          field[:units] ? "#{input} #{field[:units]}" : input
        when 'DV_COUNT', 'DV_ORDINAL'
          "<%= f.number_field :#{name}, step: 1 %>"
        when 'DV_CODED_TEXT'
          options = (field[:code_labels] || {}).map { |code, label| [label, code] }
          "<%= f.select :#{name}, #{options.inspect}, include_blank: true %>"
        when 'DV_BOOLEAN'
          "<%= f.check_box :#{name} %>"
        when 'DV_DATE'
          "<%= f.date_field :#{name} %>"
        when 'DV_TIME'
          "<%= f.time_field :#{name} %>"
        when 'DV_DATE_TIME'
          "<%= f.datetime_field :#{name} %>"
        else
          "<%= f.text_field :#{name} %>"
        end
      end

      def display_value_for(field, record_variable)
        value = "<%= #{record_variable}.#{field[:name]} %>"
        field[:rm_type] == 'DV_QUANTITY' && field[:units] ? "#{value} #{field[:units]}" : value
      end

      def range_options(field)
        lower, upper = field[:magnitude_range]
        options = +''
        options << ", min: #{lower}" if lower
        options << ", max: #{upper}" if upper
        options
      end

      def sample_value_for(field)
        case field[:column_type]
        when :float then '1.0'
        when :integer then '1'
        when :boolean then 'true'
        when :date then 'Date.current'
        when :time, :datetime then 'Time.current'
        else
          field[:code_list]&.first ? field[:code_list].first.inspect : "'test'"
        end
      end
    end
  end
end

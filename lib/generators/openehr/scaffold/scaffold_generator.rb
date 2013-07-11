require 'openehr/rm'
require 'openehr/am'
require 'openehr/parser'
require 'rails/generators/named_base'
require 'rails/generators/resource_helpers'

module OpenEHR
  module Rails
    module Generators
      class ScaffoldGenerator < ::Rails::Generators::Base
        source_root File.expand_path("../templates", __FILE__)

        def initialize(adl, *options)
          super
          @archetype = OpenEHR::Parser::ADLParser.new(adl[0]).parse
        end

        def create_root_folder
          empty_directory File.join("app/views", controller_file_path)
        end

        def generate_index
          generate_view  "index.html.erb"
        end

        def generate_show
          generate_view  "show.html.erb"
        end

        def generate_edit
          generate_view "edit.html.erb"
        end

        def generate_form
          generate_view "_form.html.erb"
        end

        protected
        def controller_file_path
          @archetype.archetype_id.value.underscore
        end

        def generate_view(filename)
          template filename, File.join("app/views", controller_file_path, filename)
        end
      end
    end
  end
end
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
          filename = "index.html.erb"
          template filename, File.join("app/views", controller_file_path, filename)
        end
        protected
        def controller_file_path
          @archetype.archetype_id.value.underscore
        end
      end
    end
  end
end

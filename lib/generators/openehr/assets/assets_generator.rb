require 'generators/openehr'
require 'rails/generators/rails/scaffold/scaffold_generator'

module Openehr
  module Generators
    class AssetsGenerator < ArchetypedBase
      source_root File.expand_path("../templates", __FILE__)

      def create_assets_directory
        empty_directory 'app/assets'
      end

      def copy_css
        dir = ::Rails::Generators::ScaffoldGenerator.source_root
        cssfile = File.join(dir, 'scaffold.css')
        create_file 'app/assets/stylesheets/scaffold.css', File.read(cssfile)
      end

      def create_scss
        template 'stylesheet.css.scss', File.join('app/assets/stylesheets', "#{model_name}.css.scss")
      end

      def create_coffeescript
        template 'javascript.js', File.join('app/assets/javascripts', "#{model_name}.js.coffee")
      end
    end
  end
end

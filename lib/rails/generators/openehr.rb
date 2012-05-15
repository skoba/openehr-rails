require 'rails/generators/named_base'

module OpenEHR
  module Rails
    module Generators
      class InitializerGenerator < ::Rails::Generators::NamedBase

      end

      autoload :InstallGenerator, 'openehr/generators'
    end
  end
end

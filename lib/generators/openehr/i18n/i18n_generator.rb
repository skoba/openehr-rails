module OpenEHR
  module Rails
    module Generators
      class I18nGenerator < ::Rails::Generators::NamedBase
        def create_i18n_file
          create_file 'config/initializers/i18n.rb'
        end
      end
    end
  end
end

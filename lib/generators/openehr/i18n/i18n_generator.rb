require 'openehr/rm'
require 'openehr/am'
require 'openehr/parser'
require 'locale/info'

module OpenEHR
  module Rails
    module Generators
      class I18nGenerator < ::Rails::Generators::NamedBase
        source_root File.expand_path '../templates', __FILE__

        def create_i18n_file
          @original_language = original_language
          @translations = translations
          template 'i18n.rb', 'config/initializers/i18n.rb'
        end

        private
        def archetype
          OpenEHR::Parser::ADLParser.new(name).parse
        end

        def original_language
          { code: original_language_code,
            text: Locale::Info.get_language(original_language_code).name }
        end

        def original_language_code
          archetype.original_language.code_string
        end

        def translations
          archetype.translations.each_key.map do |key|
            { code: key, text: Locale::Info.get_language(key).name }
          end
        end
      end
    end
  end
end

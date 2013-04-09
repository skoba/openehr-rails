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
          archetype = OpenEHR::Parser::ADLParser.new(name).parse
          original_language_code = archetype.original_language.code_string
          @original_language = { code: original_language_code,
            text: Locale::Info.get_language(original_language_code).name}
          @translations = archetype.translations.each_key.map do |key|
            { code: key, text: Locale::Info.get_language(key).name }
          end
          template 'i18n.rb', 'config/initializers/i18n.rb'
        end
      end
    end
  end
end

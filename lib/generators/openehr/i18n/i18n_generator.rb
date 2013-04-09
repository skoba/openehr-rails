# -*- coding: utf-8 -*-
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

        def create_yaml_files
          archetype.ontology.term_definitions.keys.each do |k|

            target_file = "config/locales/#{k}.yml"
            create_file target_file
            archetype.ontology.term_definitions['en'].each do |code, term|
              append_file target_file, <<-TARGET
#{k}:
 layouts:
  applications:
    #{code}: "#{term.items['text']}"
TARGET
            end
          end
        end

        private
        def archetype
          @archetype ||= OpenEHR::Parser::ADLParser.new(name).parse
        end

        def original_language
          { code: original_language_code,
            text: language_name(original_language_code) }
        end

        def original_language_code
          archetype.original_language.code_string
        end

        def translations
          archetype.translations.each_key.map do |key|
            { code: key, text: language_name(key) }
          end
        end

        def language_name(code)
          Locale::Info.get_language(code).name
        end
      end
    end
  end
end

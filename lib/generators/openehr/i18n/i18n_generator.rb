# -*- coding: utf-8 -*-
require 'openehr/rm'
require 'openehr/am'
require 'openehr/parser'
require 'locale/info'
require 'generators/openehr'

module Openehr
  module Generators
    class I18nGenerator < ArchetypedBase
      source_root File.expand_path '../templates', __FILE__

      def create_i18n_file
        @original_language = original_language
        @translations = translations
        template 'i18n.rb', 'config/initializers/i18n.rb'
      end

      def create_yaml_files
        @controller_path = archetype.archetype_id.value.underscore
        archetype.ontology.term_definitions.each do |code, terms|
          @language_code = code
          @terms = terms.map do |atcode, term|
            {atcode: atcode, item: term.items['text']}
          end
          template 'language.yml', "config/locales/#{@language_code}.yml"
        end
      end

      protected
      def original_language
        { code: original_language_code,
          text: language_name(original_language_code) }
      end

      def original_language_code
        archetype.original_language.code_string
      end

      def translations
        archetype.translations.each_key.map do |code|
          { code: code, text: language_name(code) }
        end
      end

      def language_name(code)
        Locale::Info.get_language(code).name
      end
    end
  end
end

module OpenEHR
  module Generators
    class Base < Rails::Generators::NamedBase
      def self.source_root
        @_archetype_source_root ||= File.expand_path(File.join(File.dirname(__FILE__), 'archetype', generator_name, 'templates'))
      end
    end
  end
end

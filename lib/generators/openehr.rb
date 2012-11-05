require 'rails/generators/named_base'

module OpenEHR
  module Rails
    module Generators
      class Base < ::Rails::Generators::NamedBase
        def self.source_root
          @_openehr_source_root ||= File.expand_path(File.join(File.dirname(__FILE__), 'openehr', generator_name, 'templates'))
        end
      end      
    end
  end
end

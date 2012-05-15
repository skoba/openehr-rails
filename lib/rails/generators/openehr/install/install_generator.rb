require 'rails/generators/named_base'

module Archetype
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc <<DESC
Description:
  make archtype directory and copy files
DESC

      def self.source_root
        @source_root ||= File.expand_path(File.join(File.dirname(__FILE__), 'templates'))       
      end

      def copy_archetype
        directory 'app/archetype'
      end
    end
  end
end

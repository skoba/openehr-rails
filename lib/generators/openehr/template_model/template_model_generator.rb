require 'generators/openehr'
require 'rails/generators'

module Openehr
  module Generators
    class TemplateModelGenerator < ArchetypedBase
      source_root File.expand_path("../templates", __FILE__)

      def create_template_model
        template 'template_model.rb', File.join('app/models', 'openehr_template.rb')
      end

      def create_archetype_model
        template 'archetype_model.rb', File.join('app/models', 'openehr_archetype.rb')
      end

      def create_template_migration
        migration_template 'create_openehr_templates.rb', 
                          File.join('db/migrate', "#{Time.now.strftime('%Y%m%d%H%M%S')}_create_openehr_templates.rb")
      end

      def create_archetype_migration
        migration_template 'create_openehr_archetypes.rb', 
                          File.join('db/migrate', "#{Time.now.strftime('%Y%m%d%H%M%S')}_create_openehr_archetypes.rb")
      end
    end
  end
end
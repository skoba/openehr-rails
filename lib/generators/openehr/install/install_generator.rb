module Openehr
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc <<DESC
        Description: 
        setup openEHR environment with archetype directory.
      DESC
      
      source_root File.expand_path('templates', __dir__)
      
      def create_models
        generate_model_files
        generate_migration_files
        generate_concern_files
      end
      
      def create_initializer
        template 'openehr.rb', 'config/initializers/openehr.rb'
      end
      
      def create_aql_translator
        template 'aql_translator.rb', 'lib/openehr/aql_translator.rb'
      end
      
      private
      
      def generate_model_files
        template 'models/composition.rb', 'app/models/composition.rb'
        template 'models/data_value.rb', 'app/models/data_value.rb'
        template 'models/data_structure.rb', 'app/models/data_structure.rb'
        template 'models/ehr.rb', 'app/models/ehr.rb'
        template 'models/template.rb', 'app/models/template.rb'
      end
      
      def generate_migration_files
        migration_template 'migrations/create_openehr_tables.rb',
                          'db/migrate/create_openehr_tables.rb'
      end
      
      def generate_concern_files
        template 'concerns/openehr_storable.rb', 
                'app/models/concerns/openehr_storable.rb'
        template 'concerns/aql_queryable.rb',
                'app/models/concerns/aql_queryable.rb'
      end
    end
  end
end

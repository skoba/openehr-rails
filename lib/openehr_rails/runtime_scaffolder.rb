# frozen_string_literal: true

module OpenehrRails
  # Runs the openehr:scaffold generator from inside a running Rails app
  # (admin engine "Generate UI" action): writes the OPT to its canonical
  # location, invokes the generator, migrates and reloads the routes so
  # the new resource is usable without restarting the server.
  #
  # Intended for development; gate access with
  # OpenehrRails.runtime_scaffolding_allowed?.
  class RuntimeScaffolder
    Result = Struct.new(:model_name, :route_path, keyword_init: true)

    def self.call(template, root: ::Rails.root)
      new(template, root: root).call
    end

    def initialize(template, root:)
      @template = template
      @root = Pathname.new(root)
    end

    def call(migrate: true, reload: true)
      ensure_opt_file
      run_generator
      run_migrations if migrate
      reload_routes if reload
      Result.new(model_name: model_name, route_path: model_name.pluralize)
    end

    def model_name
      OpenehrRails::Naming.model_name(@template.template_id)
    end

    def scaffolded?
      @root.join("app/models/#{model_name}.rb").exist?
    end

    private

    def opt_path
      @root.join(TemplateUploader::STORAGE_DIR, "#{@template.template_id}.opt")
    end

    # The registry stores the OPT content; materialize it for the
    # generator if no uploaded file is present.
    def ensure_opt_file
      existing = Dir.glob(@root.join(TemplateUploader::STORAGE_DIR, '*.opt')).find do |candidate|
        OpenehrRails::Naming.model_name(File.basename(candidate, '.opt')) == model_name
      end
      return @opt_path = Pathname.new(existing) if existing

      FileUtils.mkdir_p(opt_path.dirname)
      File.write(opt_path, @template.content)
      @opt_path = opt_path
    end

    def run_generator
      require 'rails/generators'
      Rails::Generators.invoke('openehr:scaffold', [@opt_path.to_s],
                               behavior: :invoke, destination_root: @root.to_s)
    end

    def run_migrations
      ActiveRecord::MigrationContext.new([@root.join('db/migrate').to_s]).migrate
      ActiveRecord::Base.connection.schema_cache.clear!
    end

    def reload_routes
      ::Rails.application.reload_routes! if defined?(::Rails.application) && ::Rails.application
    end
  end
end

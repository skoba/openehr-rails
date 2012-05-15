module OpenEHR
  module Rails
    class Railtie < ::Rails::Railtie
      generators = config.respond_to?(:app_generators) ? config.app_generators : config.generators
    end

    autoload :Generators, 'rails/generators/openehr.rb'
  end
end

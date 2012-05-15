$:.unshift(File.dirname(__FILE__))

module OpenEHR
  module Rails
    class Railtie < ::Rails::Railtie
      generators = config.respond_to?(:app_generators) ? config.app_generators : config.generators
    end
  end
end

require 'rails/all'
require 'spork'
require 'simplecov'

module OpenEHRRails
  class Application < ::Rails::Application
  end
end


require 'openehr/rails'

Spork.prefork do

  Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
  $:.unshift(File.dirname(__FILE__) + '/../lib')

  require 'openehr/rails'
  require 'ammeter/init'

  SimpleCov.start
end

Spork.each_run do

end


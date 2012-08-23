require 'rubygems'
require 'spork'
require 'rails/all'
require 'rspec/rails'
require 'ammeter/init'
require 'simplecov'

Spork.prefork do

  Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

  RSpec.configure do |config|
    #  config.fixture_path = "#{::Rails.root}/spec/fixtures"
    #  config.use_transactional_fixtures = false
    #  config.infer_base_class_for_anonymous_controllers = false
  end
  $:.unshift(File.dirname(__FILE__) + '/../lib')

  SimpleCov.start
end

Spork.each_run do

end


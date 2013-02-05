require 'rubygems'
require 'spork'
require 'rails/all'
require 'rspec/rails'
require 'ammeter/init'
require 'simplecov'
require 'thor/actions'
require 'cucumber'
require 'openehr'

Spork.prefork do

  Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

  $:.unshift(File.dirname(__FILE__) + '/../lib')

  RSpec.configure do |config|
    config.color_enabled = true
    config.filter_run :focus => true
    config.run_all_when_everything_filtered = true

    def destination_root
      return File.expand_path('../tmp', __FILE__)
    end
  end

  SimpleCov.start
end

Spork.each_run do

end


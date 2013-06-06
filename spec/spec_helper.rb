require 'rails/all'
require 'ammeter/init'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'openehr/rails'

#require 'simplecov'

# Spork.prefork do

#   SimpleCov.start
# end

# Spork.each_run do

# end


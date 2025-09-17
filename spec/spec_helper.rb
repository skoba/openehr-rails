require 'rails/all'

# Disable ActiveRecord for generator tests
begin
  ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
rescue
  # Ignore connection errors for generator tests
end

require 'ammeter/init'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}
$:.unshift(File.dirname(__FILE__) + '/../lib')
#require 'openehr/rails'

require 'simplecov'

SimpleCov.start

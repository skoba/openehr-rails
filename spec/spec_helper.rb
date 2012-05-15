require 'rubygems'
require 'spork'
require 'rails/all'

# module OpenEHR
#   module Rails
#     class Application < ::Rails::Application

#     end
#   end
# end

#SimpleCov.start

Spork.prefork do

end

Spork.each_run do

end

#Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
#  config.fixture_path = "#{::Rails.root}/spec/fixtures"
#  config.use_transactional_fixtures = false
#  config.infer_base_class_for_anonymous_controllers = false
end
$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'openehr-rails'

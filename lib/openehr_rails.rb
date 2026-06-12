require 'uri'

# Workaround for Ruby 3.4 URI compatibility
begin
  URI.class_variable_get(:@@schemes)
rescue NameError
  URI.class_variable_set(:@@schemes, {})
end

require 'openehr/am'
require 'openehr/rm'
require 'openehr/parser'

require 'openehr_rails/naming'
require 'openehr_rails/opt'
require 'openehr_rails/opt/parser'
require 'openehr_rails/opt/field_extractor'
require 'openehr_rails/storable'
require 'openehr_rails/aql_queryable'
require 'openehr_rails/template_registry'
require 'openehr_rails/template_uploader'
require 'openehr_rails/runtime_scaffolder'

require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'

module OpenehrRails
  # Runtime scaffolding (admin engine uploads + UI generation) writes
  # files into the host app; defaults to development only.
  mattr_accessor :enable_runtime_scaffolding, default: nil

  def self.runtime_scaffolding_allowed?
    return enable_runtime_scaffolding unless enable_runtime_scaffolding.nil?

    defined?(::Rails.env) && ::Rails.env.development?
  end
end

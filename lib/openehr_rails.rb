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
require 'openehr_rails/fhir/type_map'
require 'openehr_rails/fhir/profile_generator'
require 'openehr_rails/fhir/resource_registry'
require 'openehr_rails/fhir/serializer'
require 'openehr_rails/fhir/deserializer'
require 'openehr_rails/fhir/capability_statement'
require 'openehr_rails/fhir/profile_repository'

require 'active_support'
require 'active_support/core_ext/module/attribute_accessors'

module OpenehrRails
  # Runtime scaffolding (admin engine uploads + UI generation) writes
  # files into the host app; defaults to development only.
  mattr_accessor :enable_runtime_scaffolding, default: nil

  # RM graph persistence (openehr_rm_* tables): nil = auto-detect by
  # table presence, true/false = force.
  mattr_accessor :rm_persistence_enabled, default: nil

  # Defaults injected when converting stored graphs into full
  # OpenEHR::RM objects (OPT data does not carry these today).
  mattr_accessor :system_id, default: 'openehr-rails'
  mattr_accessor :default_language, default: 'en'
  mattr_accessor :default_territory, default: 'US'
  mattr_accessor :default_category, default: %w[433 event]
  mattr_accessor :default_composer_name, default: 'unknown'
  mattr_accessor :default_encoding, default: 'UTF-8'

  def self.runtime_scaffolding_allowed?
    return enable_runtime_scaffolding unless enable_runtime_scaffolding.nil?

    defined?(::Rails.env) && ::Rails.env.development?
  end
end

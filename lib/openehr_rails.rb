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

require 'openehr_rails/version'
require 'openehr_rails/naming'
require 'openehr_rails/opt'
require 'openehr_rails/opt/parser'
require 'openehr_rails/opt/field_extractor'
require 'openehr_rails/opt/remote_fetcher'
require 'openehr_rails/storable'
# openehr_rails/rm/graph_builder depends on OpenehrRails::Storable::MULTIPLE_ATTRIBUTES
# at load time, so this must come after the storable require above.
require 'openehr_rails/rm'
require 'openehr_rails/aql/errors'
require 'openehr_rails/aql/dataset_adapter'
require 'openehr_rails/aql/query_validator'
require 'openehr_rails/aql/executor'
require 'openehr_rails/aql_queryable'
require 'openehr_rails/template_registry'
require 'openehr_rails/template_uploader'
require 'openehr_rails/template_importer'
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

  # Authentication hook, run via before_action ahead of every engine
  # action (all controllers inherit from OpenehrRails::ApplicationController).
  # A zero-arity proc, instance_exec'd in the controller -- so it can use
  # request/render/redirect_to/head and any helper the host mixes into
  # ActionController::Base (e.g. Devise's authenticate_user!). Deny by
  # rendering or redirecting (standard before_action halting); some engine
  # controllers rescue_from StandardError, so a hook that raises instead
  # of rendering would be masked as a misleading error response --
  # render/redirect only.
  mattr_accessor :authenticate_with, default: nil

  # Explicit escape hatch for intentionally-open deployments (e.g. behind
  # a reverse proxy that already authenticates, or network-isolated
  # internal-only apps). Overrides the environment-based default in
  # EITHER direction: true forces access even in production; false forces
  # denial even in development.
  mattr_accessor :allow_unauthenticated_access, default: nil

  def self.unauthenticated_access_allowed?
    return allow_unauthenticated_access unless allow_unauthenticated_access.nil?
    return false unless defined?(::Rails.env)

    ::Rails.env.development? || ::Rails.env.test?
  end
end

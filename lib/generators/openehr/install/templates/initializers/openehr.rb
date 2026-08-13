# openEHR-Rails configuration.
#
# Operational templates (.opt) copied by `rails g openehr:scaffold` live in
# app/templates/operational and are registered in the openehr_templates
# table via OpenehrTemplate.from_opt_file.
require 'openehr_rails'

# Uncomment to enable runtime scaffolding in non-development environments.
# OpenehrRails.enable_runtime_scaffolding = true

# RM Persistence Layer (optional):
# Set to false to disable persisting graphs to openehr_rm_* tables.
# Defaults to auto-detect: enabled if migrations have been run.
# OpenehrRails.rm_persistence_enabled = true

# openEHR RM Object Builder defaults (injected when building OpenEHR::RM objects):
# OpenehrRails.system_id = 'openehr-rails'
# OpenehrRails.default_language = 'en'
# OpenehrRails.default_territory = 'US'
# OpenehrRails.default_category = %w[433 event]  # [code, value]
# OpenehrRails.default_composer_name = 'unknown'
# OpenehrRails.default_encoding = 'UTF-8'

# Authentication (REQUIRED before deploying outside development/test):
# the engine (admin UI, AQL console, /v1 REST API, /fhir facade) serves
# clinical data, so it denies every request with 403 in any environment
# other than development/test until you configure a hook here. The hook
# runs as a before_action inside the engine controller handling the
# request (instance_exec'd) -- deny by rendering/redirecting, not
# raising, since some engine controllers rescue_from StandardError.
#
# Devise:
# OpenehrRails.authenticate_with = -> { authenticate_user! }
#
# Bearer token:
# OpenehrRails.authenticate_with = lambda do
#   authenticate_or_request_with_http_token do |token, _options|
#     ActiveSupport::SecurityUtils.secure_compare(
#       token, Rails.application.credentials.openehr_api_token.to_s
#     )
#   end
# end
#
# Different mechanism per surface (openehr_access_scope is :admin,
# :rest_api or :fhir):
# OpenehrRails.authenticate_with = lambda do
#   openehr_access_scope == :admin ? authenticate_user! : authenticate_or_request_with_http_token { |t, _| valid_api_token?(t) }
# end
#
# Explicit opt-out for intentionally-open deployments (e.g. behind a
# reverse proxy that already authenticates, network-isolated internal
# apps) -- NOT recommended for anything reachable outside your network:
# OpenehrRails.allow_unauthenticated_access = true

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

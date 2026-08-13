# frozen_string_literal: true

#
# Rails application template for openehr-rails (the openEHR high-speed
# development environment). Bootstraps a brand new Rails app wired up
# with the engine (template registry, RM persistence, AQL, admin UI,
# FHIR facade), and optionally scaffolds the same 3 sample templates
# used by this repo's own demo (BMI / problem list / blood pressure).
#
# Usage:
#   rails new myehr -m https://raw.githubusercontent.com/skoba/openehr-rails/master/templates/openehr_template.rb
# or from a local checkout:
#   rails new myehr -m /path/to/openehr-rails/templates/openehr_template.rb
#
# Recommended `rails new` flags: --database=sqlite3 --skip-test (this
# template adds rspec-rails itself when OPENEHR_SAMPLES=1, since
# openehr:scaffold generates request specs).
#
# Env vars:
#   OPENEHR_RAILS_PATH   - reference the gem via `path:` instead of
#                          rubygems (for testing against an unreleased
#                          gem checkout, e.g. this repo's own CI)
#   OPENEHR_SAMPLES=1    - also scaffold the 3 sample OPT templates
#                          (BMI, problem list, blood pressure) with
#                          --fhir, fetched over HTTP via
#                          OpenehrRails::Opt::RemoteFetcher
#   OPENEHR_SAMPLES_BASE - base URL for the sample OPTs (default: this
#                          repo's demo_assets/templates/ on GitHub)

samples_base = ENV.fetch(
  'OPENEHR_SAMPLES_BASE',
  'https://raw.githubusercontent.com/skoba/openehr-rails/master/demo_assets/templates'
)
sample_templates = %w[bmi_calculation problem_list patient_blood_pressure]

if ENV['OPENEHR_RAILS_PATH']
  gem 'openehr-rails', path: ENV['OPENEHR_RAILS_PATH']
else
  gem 'openehr-rails', '~> 0.3'
end

if ENV['OPENEHR_SAMPLES'] == '1'
  gem_group :development, :test do
    gem 'rspec-rails'
  end
end

after_bundle do
  generate 'openehr:install'
  rails_command 'db:migrate'

  if ENV['OPENEHR_SAMPLES'] == '1'
    generate 'rspec:install'

    sample_templates.each do |name|
      generate 'openehr:scaffold', "#{samples_base}/#{name}.opt", '--fhir'
    end
    rails_command 'db:migrate'
    rails_command 'db:seed' # registers each scaffolded template (db/seeds.rb) in the openehr_templates table
  end

  # Fall back to a local (repo-only) git identity when none is
  # configured -- e.g. a fresh CI runner -- so the commit below doesn't
  # blow up with "Please tell me who you are." Doesn't touch an already-
  # configured identity (local or global).
  run 'git config --get user.email >/dev/null || git config user.email "openehr-rails-template@example.com"'
  run 'git config --get user.name  >/dev/null || git config user.name  "openehr-rails-template"'

  git add: '-A'
  git commit: %( -m "Set up openehr-rails" )

  say <<~MSG

    openehr-rails is set up. Start the server:

      bin/rails server

    Then open:
      http://localhost:3000/openehr                 (admin UI: templates, AQL console, patient timeline)
      http://localhost:3000/openehr/fhir/metadata    (FHIR R5 CapabilityStatement)

    To add your own template:

      rails g openehr:scaffold path/to/template.opt --fhir
      rails g openehr:scaffold https://example.com/template.opt --fhir

    Docs: https://github.com/skoba/openehr-rails
  MSG
end

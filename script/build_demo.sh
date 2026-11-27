#!/usr/bin/env bash
#
# build_demo.sh — builds the openehr-rails demo app from scratch.
#
# Lets anyone reproduce how an openEHR Operational Template (.opt) becomes a
# Rails resource (model/migration/controller/views/locale/FHIR profiles). It
# scaffolds three templates in turn -- BMI (OBSERVATION, numbers), problem list
# (EVALUATION, coded text and date/time) and blood pressure (OBSERVATION,
# several archetypes) -- and sets up the CRUD screens, the admin UI (/openehr)
# and the FHIR R5 facade.
#
# Usage:
#   cd /path/to/openehr-rails
#   bash script/build_demo.sh
#   cd demo && bin/rails server
#
# demo/ can be rebuilt at any time, so it is not tracked in git (.gitignore).
# Walkthrough: doc/DEMO.md (Japanese: doc/DEMO_ja.md).

set -euo pipefail

# Move to the repository root (one level above this script)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DEMO_DIR="$REPO_ROOT/demo"
ASSETS_DIR="$REPO_ROOT/demo_assets"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

# 1. Prerequisites ----------------------------------------------------------
log "Checking prerequisites"
command -v ruby   >/dev/null 2>&1 || die "ruby not found"
command -v bundle >/dev/null 2>&1 || die "bundler not found (gem install bundler)"
command -v rails  >/dev/null 2>&1 || die "rails not found (gem install rails)"
ruby -v
bundle -v
rails -v

# An existing demo/
if [ -d "$DEMO_DIR" ]; then
  if [ "${FORCE:-0}" = "1" ]; then
    warn "Removing the existing demo/ and rebuilding it (FORCE=1)"
    rm -rf "$DEMO_DIR"
  else
    read -r -p "demo/ already exists. Remove it and rebuild? [y/N] " ans
    case "$ans" in
      [yY]*) rm -rf "$DEMO_DIR" ;;
      *) die "Aborted. Move or remove the existing demo/ to rebuild it" ;;
    esac
  fi
fi

# 2. rails new --------------------------------------------------------------
log "Creating the Rails app (demo/)"
rails new demo \
  --database=sqlite3 \
  --skip-test \
  --skip-jbuilder \
  --skip-action-mailbox \
  --skip-action-cable \
  --skip-kamal \
  --skip-ci

# 3. Wire the gem and bundle install ---------------------------------------
log "Adding openehr-rails (path: '..') and rspec-rails to the Gemfile"
if ! grep -q 'gem "openehr-rails"' "$DEMO_DIR/Gemfile"; then
  printf '\n# openEHR archetype/template scaffolding (local path)\ngem "openehr-rails", path: ".."\n' >> "$DEMO_DIR/Gemfile"
fi
# The app is created with --skip-test, but openehr:scaffold writes
# spec/requests/*.rb (so the generated code can be checked with rspec).
if ! grep -q 'rspec-rails' "$DEMO_DIR/Gemfile"; then
  printf '\ngroup :development, :test do\n  gem "rspec-rails"\nend\n' >> "$DEMO_DIR/Gemfile"
fi
# Temporary (2026-09): json 3.0 changed JSON.parse's arguments, which
# activesupport 8.1.3.1's ActiveSupport::JSON.decode does not match, so reading
# and writing json columns raises ArgumentError. Remove once a Rails patch
# release fixes it (docs/backlog.md).
if ! grep -q 'gem "json"' "$DEMO_DIR/Gemfile"; then
  printf '\n# temporary: json 3.0 vs activesupport 8.1.3.1 JSON.parse arity mismatch\ngem "json", "< 3"\n' >> "$DEMO_DIR/Gemfile"
fi

cd "$DEMO_DIR"
log "bundle install"
bundle install
bin/rails generate rspec:install

# 4. openehr:install --------------------------------------------------------
log "openehr:install (template registry model, RM tables, admin engine)"
bin/rails generate openehr:install
bin/rails db:migrate

# 5. Scaffold the BMI template (OBSERVATION, numbers) ----------------------
log "Scaffolding the BMI template (--fhir)"
bin/rails generate openehr:scaffold "$ASSETS_DIR/templates/bmi_calculation.opt" --fhir
bin/rails db:migrate
bin/rails db:seed

# 6. Scaffold the problem list (EVALUATION, coded text and date/time)
log "Scaffolding the problem list (ProblemList) template (--fhir)"
bin/rails generate openehr:scaffold "$ASSETS_DIR/templates/problem_list.opt" --fhir
bin/rails db:migrate
bin/rails db:seed

# 6.5 Scaffold the blood pressure template (OBSERVATION, several archetypes:
#     pulse plus systolic/diastolic pressure)
log "Scaffolding the blood pressure (PatientBloodPressure) template (--fhir)"
bin/rails generate openehr:scaffold "$ASSETS_DIR/templates/patient_blood_pressure.opt" --fhir
bin/rails db:migrate
bin/rails db:seed

# 7. Load the sample data ---------------------------------------------------
log "Loading sample records (demo_assets/demo_seed.rb)"
bin/rails runner "$ASSETS_DIR/demo_seed.rb"

# Show the generated routes (the actual paths are as listed here) ---------
log "Generated routes"
bin/rails routes | grep -E 'bmi|problemlist|patient_blood_pressure|openehr' || true

# 8. Done -------------------------------------------------------------------
cat <<'MSG'

============================================================
 The demo app is ready.
------------------------------------------------------------
 Start the server:
   cd demo && bin/rails server

 URLs (http://localhost:3000):
   CRUD     : /bmi_calculations , /problemlists , /patient_blood_pressures
   Admin UI : /openehr
   FHIR     : /openehr/fhir/metadata

 Walkthrough: doc/DEMO.md (Japanese: doc/DEMO_ja.md)
============================================================
MSG

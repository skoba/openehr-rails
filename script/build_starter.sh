#!/usr/bin/env bash
#
# build_starter.sh — generates a standalone "starter" Rails app repo,
# meant to be pushed to its own GitHub repository and marked as a
# "Template repository" there (Settings -> Template repository), so
# `gh repo create --template` / GitHub's "Use this template" button hand
# someone a working openehr-rails app instead of an empty repo.
#
# Unlike demo/ (built by script/build_demo.sh, which references this gem
# via `path: ".."` and only makes sense inside this checkout), the
# starter app depends on the real, published `openehr-rails` gem, via
# templates/openehr_template.rb -- this script is a thin wrapper around
# `rails new -m templates/openehr_template.rb` that also adds a starter
# README and a minimal CI workflow to the generated repo.
#
# Usage:
#   bash script/build_starter.sh
#   cd ../openehr-rails-starter
#   git remote add origin git@github.com:<you>/openehr-rails-starter.git
#   git push -u origin master
#   # then on GitHub: Settings -> Template repository -> enable
#
# Env:
#   STARTER_DIR         - where to generate (default: ../openehr-rails-starter)
#   OPENEHR_RAILS_PATH   - passed through to templates/openehr_template.rb;
#                          set this to this repo's root to test-build the
#                          starter locally before 0.3.0 is actually
#                          published on RubyGems (the default Gemfile
#                          reference, "~> 0.3", won't resolve until then).
#   OPENEHR_SAMPLES=1    - also passed through: scaffold the 3 sample
#                          templates (BMI, problem list, blood pressure).
#   FORCE=1              - overwrite an existing STARTER_DIR without prompting

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STARTER_DIR="${STARTER_DIR:-$REPO_ROOT/../openehr-rails-starter}"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

log "Checking prerequisites"
command -v ruby   >/dev/null 2>&1 || die "ruby not found"
command -v bundle >/dev/null 2>&1 || die "bundler not found (gem install bundler)"
command -v rails  >/dev/null 2>&1 || die "rails not found (gem install rails)"
ruby -v
bundle -v
rails -v

if [ -d "$STARTER_DIR" ]; then
  if [ "${FORCE:-0}" = "1" ]; then
    warn "removing existing $STARTER_DIR (FORCE=1)"
    rm -rf "$STARTER_DIR"
  else
    read -r -p "$STARTER_DIR already exists. Remove and rebuild? [y/N] " ans
    case "$ans" in
      [yY]*) rm -rf "$STARTER_DIR" ;;
      *) die "aborted. Remove/move $STARTER_DIR yourself to rebuild." ;;
    esac
  fi
fi

if [ -z "${OPENEHR_RAILS_PATH:-}" ]; then
  warn "OPENEHR_RAILS_PATH is not set -- the generated Gemfile will reference" \
       "gem \"openehr-rails\", \"~> 0.3\", which will only resolve once 0.3.0 is" \
       "actually published on RubyGems. Set OPENEHR_RAILS_PATH=$REPO_ROOT to" \
       "test-build against this checkout instead."
fi

log "Generating starter app at $STARTER_DIR"
rails new "$STARTER_DIR" \
  --database=sqlite3 \
  --skip-test \
  --skip-jbuilder \
  --skip-action-mailbox \
  --skip-action-cable \
  --skip-kamal \
  --skip-ci \
  -m "$REPO_ROOT/templates/openehr_template.rb"

log "Adding starter README and CI workflow"

cat > "$STARTER_DIR/README.md" <<'MSG'
# openehr-rails starter

A Rails app pre-wired with [openehr-rails](https://github.com/skoba/openehr-rails),
the openEHR high-speed development environment for Rails. Generated from
[`templates/openehr_template.rb`](https://github.com/skoba/openehr-rails/blob/master/templates/openehr_template.rb).

## Run it

```sh
bin/rails db:migrate
bin/rails server
```

Then open:

- <http://localhost:3000/openehr> -- admin UI: template management, AQL
  query console, patient timeline
- <http://localhost:3000/openehr/fhir/metadata> -- FHIR R5 CapabilityStatement

## Add your own openEHR template

```sh
rails g openehr:scaffold path/to/template.opt --fhir
rails g openehr:scaffold https://example.com/template.opt --fhir
```

This generates a model, migration, controller, views, i18n locale, and
(with `--fhir`) FHIR R5 `StructureDefinition` profiles from the
Operational Template.

## Docs

See the [openehr-rails README](https://github.com/skoba/openehr-rails) and
[demo walkthrough](https://github.com/skoba/openehr-rails/blob/master/doc/DEMO_ja.md).
MSG

mkdir -p "$STARTER_DIR/.github/workflows"
cat > "$STARTER_DIR/.github/workflows/ci.yml" <<'YAML'
name: CI

on:
  push:
  pull_request:

jobs:
  spec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '4.0'
          bundler-cache: true
      - run: bundle exec rspec
YAML

cd "$STARTER_DIR"
git add -A
git commit -q -m "Add starter README and CI workflow"

cat <<MSG

============================================================
 Starter repo generated at: $STARTER_DIR
------------------------------------------------------------
 Next steps to publish as a GitHub template repository:
   cd $STARTER_DIR
   git remote add origin git@github.com:<you>/openehr-rails-starter.git
   git push -u origin master
   # then on GitHub: Settings -> Template repository -> enable
============================================================
MSG

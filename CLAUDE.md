# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Principle

Follow the TDD framework as advocated by t-wada:
- 🔴 Red: Write a failing test
- 🟢 Green: Write the minimal implementation to pass the test
- 🔵 Refactor: Improve the code while keeping tests green
- Take small steps
- Start with fake implementation (hard-coded values)
- Use triangulation to generalize
- Direct implementation is OK when the solution is obvious
- Keep the test list constantly updated
- Write tests for areas of concern first
- opt files must not be changed automatically.

## Working with implementation agents (e.g. Codex)

Codex delivers only working-tree changes; it does not commit. Claude Code reviews the
diff, then commits, recording the implementer in a commit message trailer (e.g.
`Implemented-by: Codex`).

## Release convention

Before tagging, make the final semver determination from the actual content of
`[Unreleased]`, not from a pre-assigned version number. If the instructed version number
contradicts the actual content, stop instead of tagging and ask for re-arbitration.

## Verification

- **Verify against the repo before recording a fact in it**, even when a prompt or an
  earlier report already stated it as true - a premise that went unverified once tends
  to get repeated, not corrected, if the next write also skips checking (e.g. "CI is
  unconfigured" repeated across two turns before anyone ran `gh run list`).

## Project Overview

This is `openehr-rails`, a Rails engine gem that turns an openEHR Operational Template (`.opt`, ADL2/XML) into a working Rails resource in one command: `rails generate openehr:scaffold path/to/template.opt --fhir` emits a model, migration, controller, views, i18n locale, and (with `--fhir`) HL7 FHIR R5 `StructureDefinition` profiles. Generated models persist both as typed columns (for forms/search) and as full openEHR RM data (canonical JSON + a typed node graph with immutable-append versioning), and are queryable via a growing AQL surface. A mountable admin engine (`/openehr`) provides template upload/management, runtime scaffolding, and a FHIR R5 facade. Legacy ADL-archetype-only generators (model/controller/migration/helper/assets/i18n/template/template_model, based on `Openehr::Generators::ArchetypedBase`) have been removed — OPT is the only supported input format for scaffolding.

## Key Commands

**Testing:**
- `rake spec` - Run all RSpec tests
- `rake` - Default task runs specs
- `bundle exec rspec spec/path/to/specific_spec.rb` - Run specific test file

**Development:**
- `bundle install` - Install dependencies
- `bundle exec rake` - Run tests via bundler
- `bundle exec guard` - Run Guard for automated testing (requires guard-rspec)

**Gem Development:**
- `rake build` - Build the gem (via bundler/gem_tasks)
- `rake install` - Install the gem locally
- `rake release` - Release the gem

**Demo app** (reproducible, git-ignored): `bash script/build_demo.sh` builds a Rails 8 app in `demo/` from the OPTs and seed data in `demo_assets/`, scaffolding three templates (BMI, problem list, blood pressure) with FHIR profiles. See `doc/DEMO_ja.md` for the full walkthrough.

## Architecture & Structure

### Generators (`lib/generators/openehr/`)

- `install/` - one-time setup: mounts the engine at `/openehr`, creates the `OpenehrTemplate` registry model and the `openehr_ehrs` / `openehr_rm_*` RM persistence tables.
- `scaffold/` - the core generator. Takes an `.opt` file (or, per the roadmap, a remote URL), parses it via `OpenehrRails::Opt::Parser`, extracts fields via `OpenehrRails::Opt::FieldExtractor`, and emits model/migration/controller/views/locale/request-spec/routes. `--namespace` and `--fhir` options available.
- `fhir_profile/` - emits FHIR R5 `StructureDefinition` JSON per OPT entry into `app/fhir/profiles/`.

### Runtime library (`lib/openehr_rails/`)

- `opt.rb`, `opt/parser.rb`, `opt/field_extractor.rb` - OPT parsing (subclasses `OpenEHR::Parser::OPTParser` from the `openehr` gem) and flattening of ENTRY/ELEMENT constraints into field hashes (`FIELD_MAP` is the single source of truth tying a generated column to an RM path + data type).
- `storable.rb` - mixed into scaffolded models (`OpenehrRails::Storable`): on save, builds a canonical openEHR RM Composition from `FIELD_MAP`, caches it as JSON (`rm_composition` column), and persists it into the RM graph.
- `rm/` - the RM persistence layer: `Composition`/`Node`/`DataValue` (STI, `openehr_rm_*` tables), `GraphBuilder` (canonical JSON → graph rows), `CanonicalSerializer` (graph → canonical JSON, round-trip invariant), `GraphPersister` (immutable-append versioning), `RmObjectBuilder` (graph → real `OpenEHR::RM` objects), `Ehr`/`Contribution`/`Version` (audit trail).
- `aql_queryable.rb` - `Model.find_by_path` (FIELD_MAP lookup with RM-graph fallback); full AQL query support is planned to build on the same path-to-column resolution (see roadmap in the project's plan history).
- `template_registry.rb`, `template_uploader.rb`, `runtime_scaffolder.rb` - the `OpenehrTemplate` model (supports both OPT and legacy ADL archetype registration) and the admin engine's upload + in-process `openehr:scaffold` invocation.
- `fhir/` - FHIR R5 facade: profile generation, canonical-RM ⇄ FHIR serialization, resource registry, capability statement, served at `/openehr/fhir` by `app/controllers/openehr_rails/fhir_controller.rb`.

### Testing Structure

- RSpec with `ammeter` for generator specs; in-memory SQLite (`spec/support/active_record.rb`) for RM-layer specs.
- `spec/generators/openehr/{install,scaffold,fhir_profile}/` - generator specs (only these three generators remain).
- `spec/openehr_rails/{opt,rm,fhir}/`, `spec/openehr_rails/*_spec.rb` - runtime library specs.
- `spec/models/openehr_template_spec.rb`, `spec/unit/opt_parser_spec.rb` - registry model and parser specs.
- OPT fixtures live in `spec/generators/templates/` and `spec/templates/`; do not hand-edit an existing `.opt` fixture (add a new one instead) — **opt files must not be changed automatically.**
- Fixtures fall into four kinds; each fixture's leading comment must say which kind it is:
  - **real** — a genuine artifact (CKM export, Archetype Designer output, a real host-app
    template), used as-is.
  - **reduced** — a trimmed-down real artifact; the comment must name the real source it
    was reduced from.
  - **synthetic** — hand-authored, not derived from any real artifact. real/reduced are
    preferred by default; synthetic is only for structural test cases whose reproduction
    conditions can't be controlled with a real artifact. The leading comment must say it's
    synthetic and cite its design authority (e.g. a design doc section). Archetype
    IDs/at-codes should use self-evidently invented names that can't be mistaken for real
    ones — don't rename an existing fixture to fix this after the fact; its at-codes/
    archetype IDs are reference anchors other specs/docs already point to, and freezing
    those anchors takes priority.
  - **security** — built to exercise an attack/abuse case; the comment must say it is not
    a clinical artifact.
  - A fixture's provenance comment must describe its lineage as measured (checked against
    the actual design/implementation record), not as instructed — if an instructed lineage
    doesn't match what actually went into the fixture, write it to match reality instead.
  - Example: `spec/templates/lab_result_report_reduced.opt` is **synthetic** (design
    authority: `docs/design/fix-terminology-scope-plan.md` §4; lineage confirmed
    2026-08-22) — its filename says "reduced" for historical reasons, but per this
    convention its actual kind is synthetic; the name stays as-is (reference anchor).

## Development Notes

- Ruby 3.3+ required (raised from 3.0 in 2026-08 to track the `openehr` gem dependency dropping Ruby 3.2 support at EOL); CI matrix covers 3.3/3.4/4.0, local dev pinned via `.ruby-version` (currently 4.0.6)
- Rails 7.0+ and Rails 8.x supported (CI matrix: `gemfiles/rails_{7_2,8_0,8_1}.gemfile`; demo app runs on Rails 8.1)
- URI compatibility workaround implemented for Ruby 3.4
- `ostruct` is an explicit development dependency — it left Ruby's default gems as of 4.0, and a couple of specs use `OpenStruct` as a lightweight test double
- Guard setup available for TDD workflow
- RuboCop Rails linting configured
- SimpleCov for test coverage
- `openehr` gem dependency; see the gem's own README/CHANGELOG for OPT-parser and AQL-engine capabilities and known gaps before relying on either.
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - Unreleased

### Added
- `rails g openehr:scaffold`/`openehr:fhir_profile` now accept an OPT URL in
  place of a local path, via a new `OpenehrRails::Opt::RemoteFetcher`
  (redirect-following, timeout- and size-bounded HTTP(S) fetch that
  validates the response actually parses as an operational template).
- Admin UI (`/openehr`) gained a URL-import field (`OpenehrRails::TemplateImporter`),
  the URL counterpart to the existing drag & drop upload.
- AQL query support: `OpenehrRails::Aql` (dataset adapter, query validator,
  executor) and a `Model.aql(query, params:)` scope on every scaffolded
  model, plus a browser AQL console at `/openehr/query`.
- openEHR REST API surface at `/openehr/v1`: `EHR`, `EHR_STATUS`,
  `COMPOSITION` (create/read/update/delete with optimistic concurrency),
  and `QUERY` (AQL).
- Patient timeline UI at `/openehr/ehrs` (per-EHR composition history,
  grouped by date, with version history disclosure).
- Docker: `docker/demo.Dockerfile` + `docker/docker-compose.yml` run the
  full demo app in a container with no local Ruby/Rails install needed;
  `.devcontainer/` for gem development itself.
- CI matrix expanded to Ruby 3.2/3.3/3.4/4.0 x Rails 7.2/8.0/8.1
  (`gemfiles/rails_{7_2,8_0,8_1}.gemfile`), plus a demo-smoke job that
  builds the demo app and runs its generated request specs end to end.
- `LICENSE` file (Apache License 2.0, matching the gemspec's declared
  license -- previously declared but not actually included in the repo).

### Changed
- Upgraded the `openehr` runtime dependency from `~> 1.3.0` to `~> 2.0`
  (currently resolves to 2.0.2).
- `gem.license` corrected to the valid SPDX identifier `Apache-2.0`
  (was the non-SPDX string `"Apache 2.0"`).
- Added `gem.metadata` (`source_code_uri`, `changelog_uri`,
  `bug_tracker_uri`, `rubygems_mfa_required`) and dropped the deprecated
  `gem.test_files` assignment.

### Fixed
- `OpenehrRails::Rm` was never `require`d by `lib/openehr_rails.rb`,
  silently disabling the entire RM persistence layer (typed node graph,
  AQL, versioning) in any real host application -- it only appeared to
  work in this gem's own test suite because the spec support file
  required it separately. This was the most significant bug found during
  the 2.0 upgrade work.
- `OpenehrRails::Opt::Parser`'s raw-content-vs-path detection didn't
  account for a leading UTF-8 BOM, so any BOM-prefixed OPT (common in
  real-world exports) misdetected as a file path and crashed. Affected
  every raw-content caller (`TemplateUploader`, `TemplateRegistry`,
  `Fhir::ProfileRepository`, `RemoteFetcher`), not just one code path.
- `RmObjectBuilder#build_composition` never set `uid:`, so
  `SELECT c/uid/value` always returned nil.
- `EventContext#setting` used a raw `CODE_PHRASE` where openehr 2.0
  requires a `DV_CODED_TEXT`.

### Removed
- Legacy ADL-archetype-only generators (`model`/`controller`/`migration`/
  `helper`/`assets`/`i18n`/`template`/`template_model`, and their shared
  `Openehr::Generators::ArchetypedBase`). OPT is now the only supported
  scaffolding input format; `OpenehrTemplate.from_adl_file` (ADL
  *registration*, not scaffolding) is unaffected.
- The `ckm_client` gem dependency (only used by the removed legacy
  generators).

## [0.2.2] and earlier

Predates this changelog. See `git log` for history back to the project's
first commit in 2012.

# Backlog

Non-blocking follow-ups noted during work on the upstream sprint queue. Not scheduled;
pick up when the relevant gate opens or when convenient alongside other work in the same
area. No code changes accompany entries here — this file is a record only.

## CI status (verified, not a follow-up item)

Both `.github/workflows/ci.yml` (`rspec` matrix on Ruby 3.3/3.4/4.0 x Rails
7.2/8.0/8.1, plus `demo-smoke` and `application template smoke test` jobs; triggers
on `push` to `master`, all `pull_request`s, and `workflow_call`) and
`.github/workflows/release.yml` (triggers on `v*` tags, reuses `ci.yml` via
`workflow_call`, then runs a RubyGems release job) exist on `master` — introduced at
`412712d` (2026-08-12) and `2263298` (2026-08-13) respectively — and were confirmed
actually running, not just present:

- PR #26 (`fix/field-extractor-terminology-scope`): `pull_request` runs `32549486071`
  and `32550157259` (2026-08-22, both success), post-merge `master` `push` run
  `32550193330` (success). The merge landed (03:53:04Z) about 1m43s before the final
  PR run finished (03:54:47Z) — CI ran and passed, but this doesn't demonstrate
  merge-blocking enforcement.
- Tag `v0.4.1`: `release.yml` run `32550344344` (2026-08-22T03:56:26Z) — all 11 reused
  CI jobs green, but the run's overall conclusion is **failure**: the `Release to
  RubyGems` job's `Release` step (`rubygems/release-gem@v1`) fails at "Configure
  trusted publishing credentials" ("No trusted publisher configured for this workflow
  found on https://rubygems.org for audience rubygems.org"); the actual gem-push
  sub-steps are skipped, so CI never attempted to publish. rubygems.org's 0.4.1
  listing was published by the human running `gem push` manually — no harm to the
  actual release, only to the workflow run's color. Same failure shape on every tag
  to date: v0.3.0 (runs `31655140867`, `31655495221`, `31655778244`) and v0.4.0 (run
  `31660884406`), both failure. **This is structural, not incidental**: as long as
  `release.yml` keeps a live RubyGems-publish step while the actual publish stays a
  manual human `gem push` (the current, intended operating model), every future tag
  push will reproduce the same red run. See "Release automation" below.
- Most recent `master` push at the time of this record (`4055ec3`): CI run
  `32569774700`, success.

Recorded here after this file previously claimed "this repo currently has no CI
workflow gating pull requests" — wrong on both existence and execution. This file is
the primary record for openehr-rails CI/release facts; openehr-ruby's own
`docs/backlog.md` defers to it rather than duplicating (see that file's 2026-08-23
correction, commit `bf17be7`) — do not duplicate this record back into openehr-ruby.

**Release automation fix landed (2026-08-23, PR #28, `Fixes #27`)**: `release.yml`'s
RubyGems-publish job is gone; tag pushes now run `ci` + `rake build` +
`actions/upload-artifact` only (see "Release automation" below for the item this
closes). Also bumped `actions/checkout` v4 -> v7 to clear the Node 20 deprecation
warning noted in the v0.4.1 entry above. Verified, not just green: PR #28's own
`pull_request` run `32611109196` — all 11 `ci.yml` jobs success, and the Node 20
deprecation annotation is gone from every one of those 11 jobs (checked via the
GitHub check-runs annotations API, not just the run log — each job's annotations
array is empty, `[]`). Post-merge `master` `push` run `32611237453` — success. The
renamed `build` job in `release.yml` (with `actions/checkout@v7` and the new
`actions/upload-artifact@v7` step) is tag-triggered only and was not exercised by
either of those runs; per PR #28's own body, no test tag was pushed to verify it —
that verification is deferred to the next real release (>= 0.5.0), not simulated.

## Release automation

**Done (2026-08-23, PR #28)** — kept below for the original rationale; see the CI
status entry above for verification details.

- **Unify the release path**: remove `release.yml`'s RubyGems-publish job/step and
  change tag-push handling to CI + `gem build` + artifact upload only, so the workflow
  matches how releases are actually done today (human-gated `gem push`) and stops
  going red on every tag for a step that was never meant to run automatically.
  Automatic publishing via RubyGems Trusted Publishing can be re-evaluated when the
  project's planned December public release and external-contributor model are
  actually being designed — revisit the tag-before-inventory convention (`CLAUDE.md`'s
  "Release convention" section) together with that decision at the same time, since
  automatic publishing changes what "ready to tag" needs to mean. Timing: before the
  next release (>= 0.5.0, per the "Versioning" item below). Out of scope for this
  docs-only pass — implementing the workflow change goes through an Issue (once
  ticket-driven work applies to it) plus the normal explore → plan → approval gate,
  not a direct docs commit.

## From #25 / PR #26 (FieldExtractor terminology scope fix, 2026-08-22)

- **Multi-level nesting regression test (CLUSTER in CLUSTER)**: the 0.4.1 fix and its
  regression spec (`spec/openehr_rails/opt/field_extractor_embedded_archetype_spec.rb`)
  cover one level of embedding (entry -> embedded CLUSTER). The underlying walk in
  `FieldExtractor#collect_elements` is recursive and should handle a CLUSTER embedded
  inside another embedded CLUSTER the same way, but this is currently unverified by any
  test. Add a fixture/spec covering two levels of `C_ARCHETYPE_ROOT` nesting (openehr-ruby's
  `spec/lib/openehr/opt_parser/eReferral.opt` already has a real two-level case:
  `OBSERVATION.lab_test` -> `OBSERVATION.imaging` -> `CLUSTER.imaging`, per
  `docs/design/fix-terminology-scope-plan.md` section 4). Suitable for a follow-on PR, not
  urgent.

## Compatibility

- **STRICT-incompatible fixture: 1 known case** — `spec/templates/lab_result_report_reduced.opt`'s
  leading comment uses `--` as an em dash (a double hyphen, invalid inside an XML comment);
  under STRICT-mode XML parsing this file would fail to parse at all. See
  openehr-ruby#36. Not fixed now — the current form is a live reproduction case for #36; if
  #36 moves toward making STRICT the default, this comment's punctuation is the prerequisite
  fix on this repo's side.

## Fixture conventions

- **Licensed terminology-code literals in spec expectations: keep minimal, cite the
  source fixture's file:line.** Adopted from Anlage's C2 firewall precedent (SNOMED
  CT is a licensed terminology; reproducing its codes verbatim in more places than
  necessary widens exposure for no test-coverage benefit). Applies to SNOMED CT
  specifically; **LOINC is exempt** (permissively licensed). Current count (#30,
  2026-08-25): **2 SNOMED literal occurrences** in spec expectation code, both the
  same code value `60621009`, both traceable to the same source fixture line --
  `spec/openehr_rails/opt/field_extractor_binding_spec.rb:40` and
  `spec/openehr_rails/opt/parser_term_bindings_spec.rb:28`, both citing
  `spec/templates/bmi_calculation_without_uid.opt:1689` (and the identical
  `spec/generators/templates/bmi_calculation.opt:1692`). No new SNOMED literal was
  introduced by #30 -- reused the code already present in these existing fixtures.

## Versioning

- **Next release must be >= 0.5.0, regardless of its own content**, to retroactively
  acknowledge in the version series that 0.4.1 was substantively a minor release (see the
  errata in `CHANGELOG.md`'s `[0.4.1]` entry and the release convention added to
  `CLAUDE.md`). Applies even if the next release's own changes would otherwise only
  warrant a patch bump.

## December public release prep

- **Issue templates: done (2026-08-23, #29)** — `.github/ISSUE_TEMPLATE/` (bug_report,
  enhancement, config.yml) is in place, along with `CLAUDE.md`'s "Ticket-driven
  workflow" section.
- **demo_assets README**: deferred to December prep. Note: no prior record of this
  deferral was found anywhere in this repo's docs (`docs/`, `CLAUDE.md`,
  `demo_assets/`) at the time of writing this entry — `demo_assets/` currently has no
  README at all, only `demo_seed.rb` and `templates/`. Recording it here now as the
  first record, not as confirmation of an earlier one.

## Queue gating (do not start without an explicit go-ahead)

- **#3** (registry checksum/version/status): gated on Anlage Slice 1 operational experience,
  targeted around October.
- **#4** (ValueBuilders extraction): gated on Anlage Slice 4 stabilizing and Anlage's
  duplicate-method inventory being produced first.
- **#2** (constraint -> HTML attribute mapping extraction): gated on a generality decision
  after Anlage Slice 4; whether to even start is undecided.

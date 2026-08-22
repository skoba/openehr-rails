# Backlog

Non-blocking follow-ups noted during work on the upstream sprint queue. Not scheduled;
pick up when the relevant gate opens or when convenient alongside other work in the same
area. No code changes accompany entries here — this file is a record only.

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
- **PR-triggered minimal CI (rspec)**: this repo currently has no CI workflow gating pull
  requests — `bundle exec rspec` was run manually before merging #26. Worth adding a minimal
  GitHub Actions workflow (just `bundle exec rspec` on PR) before the project's planned
  public release (targeted around December). Optional until then.

## Versioning

- **Next release must be >= 0.5.0, regardless of its own content**, to retroactively
  acknowledge in the version series that 0.4.1 was substantively a minor release (see the
  errata in `CHANGELOG.md`'s `[0.4.1]` entry and the release convention added to
  `CLAUDE.md`). Applies even if the next release's own changes would otherwise only
  warrant a patch bump.

## Queue gating (do not start without an explicit go-ahead)

- **#3** (registry checksum/version/status): gated on Anlage Slice 1 operational experience,
  targeted around October.
- **#4** (ValueBuilders extraction): gated on Anlage Slice 4 stabilizing and Anlage's
  duplicate-method inventory being produced first.
- **#2** (constraint -> HTML attribute mapping extraction): gated on a generality decision
  after Anlage Slice 4; whether to even start is undecided.

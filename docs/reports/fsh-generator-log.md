# FshGenerator progress log

R1〜.

---

## R1 -- Filing and design doc (Step 0-1)

Filed `skoba/openehr-rails#32` (goal Issue). Design authority is
`skoba/anlage`'s already-approved `docs/design/fsh-plan.md`
(2026-08-26 ruling) -- this Issue implements that plan's gem-level
commit split, not a fresh design.

Confirmed the input contract this Issue depends on is already live
(`skoba/openehr-rails#30`, shipped 0.5.0): `FieldExtractor#entries[].
fields[]` always carries `value_set_uri` and `code_bindings`
(`field_extractor.rb:160-177`).

Checked fixture leaf-field counts directly (`bundle exec ruby` with
`require 'active_record'; require 'openehr_rails'` -- `openehr_rails`
needs ActiveRecord loaded first, this repo has no `bin/rails`):

- `bmi_calculation.opt` / `bmi_calculation_without_uid.opt`: `height.v2`
  (1 leaf), `body_weight.v2` (1 leaf), `body_mass_index.v2` (**2
  leaves** -- and `at0004` already carries real SNOMED-CT (`60621009`)
  + LOINC `code_binding`, so this one entry covers both multi-leaf
  `component` slicing and code_binding in a single fixture)
- `problem_list.opt`: `problem_diagnosis.v1`, 5 leaves;
  `value_set_binding` (ICD-11) on `at0002`
- `lab_result_report_reduced.opt`: `laboratory_test_result.v1`, 3 leaves
- `sample_blood_pressure.opt`: crashes on parse (`ArgumentError:
  invalid archetype id form`, pre-existing and unrelated to this
  Issue -- not investigated further, not needed for this fixture set)

No new SNOMED literal budget needed -- all binding demonstrations reuse
codes already checked into this repo's fixtures.

Design doc written: `docs/design/fsh-generator-plan.md`. Proceeding to
implementation (Codex, reviewed and committed by Claude Code per this
repo's division of labor).

---

## R2 -- Implementation, two correction rounds, commit `5f669af` (2026-08-26)

### Round 0: Codex's first delivery

Codex implemented `FshGenerator` covering the full v1 scope table.
Self-reported: "SUSHI 3.16.0 was present, but could not finish loading
its R5 package under restricted network access" -- Codex's own sandbox
could not actually verify the generated FSH compiles. Claude Code has
unrestricted network access in this session and re-verified directly.

### Round 1 finding: conflicting CodeableConcept assignments

Regenerated FSH from Codex's actual committed code (not a
paraphrase) and piped it through `sushi` (v3.16.0, real local install)
myself. `bmi_calculation.opt`'s `body_mass_index.v2` (2 code_bindings
on `at0004`: SNOMED-CT + LOINC) produced:

```
error Cannot assign http://snomed.info/sct to this element; a different
uri is already assigned: "http://openehr.org/ckm/archetypes".
error Cannot assign http://loinc.org to this element; a different uri
is already assigned: "http://openehr.org/ckm/archetypes".
```

Root cause: the original `binding_rules` wrote one `* path =
SYSTEM#code` fixed-value assignment per `code_bindings` entry, stacked
after the archetype_id anchor's `.coding.system`/`.coding.code` pair.
`* path = SYSTEM#code` is FSH shorthand for fixing an *entire*
CodeableConcept to one coding -- writing it twice (or after an
existing `.coding.system`/`.coding.code` pair) is a conflicting
reassignment of the same slot, not an append.

Explored the fix space empirically (all runs actually compiled with
`sushi`, not assumed):
- `code.coding[0]`/`code.coding[1]` explicit indexing without a prior
  slicing declaration: **fails** ("No element found at path
  code.coding[0]") -- FHIR profile differentials don't support
  indexing into an un-sliced repeating element this way.
- `code.coding[+]`/`[=]` append syntax, same issue: **fails**,
  identical error.
- Unindexed `code.coding.system = X` / `code.coding.code = Y` alone
  (no second coding attempted): **compiles** (0 Errors) -- but this
  form sets a *pattern* on the coding sub-elements
  (`patternUri`/`patternCode` in the resulting differential), not an
  indexed instance value, which is why indexing on top of it doesn't
  work.
- **Slicing `code.coding` by the `system` value discriminator, one
  named slice per source** (`ckm` for the archetype_id anchor, one per
  `code_bindings` entry, using the terminology alias downcased as the
  slice name): **compiles, 0 Errors**, both standalone (`code.coding`)
  and nested inside a `component[slice].code.coding` path. This is the
  fix that shipped.

Sent Codex the exact verified-working FSH pattern (both the standalone
and nested-in-component forms, copy-pasteable) plus the failing
pattern and its error, and asked for a rewrite -- not a vague "fix the
conflict" instruction. Codex's fix matches: `code_rules` now branches
on whether `bindings` is empty (`simple_code_rules`, unchanged
unindexed form) vs non-empty (new sliced form via `binding_slices`).

### Round 2 finding: `component` doesn't exist on `Condition`

Re-verified again after the round-1 fix -- `bmi_calculation.opt`
(all-`Observation` entries) now compiles with **0 Errors**, confirmed
independently (regenerated from the committed code, not from Codex's
pasted example). `problem_list.opt` (single `EVALUATION` entry, 5
leaves) does not: **29 errors**, all `"No element found at path
component..."` for `Condition`.

Root cause: `TypeMap::ENTRY_RESOURCES` maps `EVALUATION` → `Condition`
(`type_map.rb:14`). `Condition` has no `component` element -- that's
`Observation`-specific in FHIR R5. `FshGenerator`'s multi-leaf branch
(mirroring `ProfileGenerator#component_elements`) always emits
`component`-path rules whenever `entry[:fields].size > 1`, with no
check for whether the target `resource_type` actually has a
`component` slot. This is a **pre-existing gap**, not something this
Issue introduced -- `ProfileGenerator`'s JSON output for the same
fixture almost certainly has the identical semantic defect, just never
caught (JSON isn't schema-validated the way FSH is by Sushi, and
`profile_generator_spec.rb` only exercises all-`Observation` fixtures).

Filed separately: `skoba/openehr-rails#33`. Out of scope for `#32` --
needs its own explore/plan (candidate directions: an extension,
restricting multi-leaf support to `Observation`-mapped entries with an
explicit documented limitation, or something else not yet decided).

Narrowed `#32`'s scope to match reality rather than over-claim: added
a 2-line code comment on the multi-leaf branch citing `#33`, and a
CHANGELOG note distinguishing "Observation-mapped output is
Sushi-verified" from "multi-leaf non-Observation entries have a known
gap tracked as #33". The `value_set_binding` spec assertion for
`problem_list.opt` stays as a text-level substring check (the `from
<uri> (required)` write itself is correct FSH, verified in isolation
in `docs/reports/fsh-log.md` R1 in `skoba/anlage`) -- it does not claim
whole-document Sushi compilation, which would be false for this
fixture.

### Final verification (Claude Code, independent of Codex's own reports)

- Regenerated FSH from the final committed `fsh_generator.rb` for both
  `bmi_calculation.opt` and `problem_list.opt`, piped each through
  `sushi` directly: **0 Errors** for `bmi_calculation.opt` (3
  profiles), **29 errors** for `problem_list.opt` (expected, tracked
  as `#33`, not a regression from anything this Issue claims)
- `bundle exec rspec spec/openehr_rails/fhir/`: 28 examples, 0 failures
- `bundle exec rspec` (full suite, this session's own environment, not
  Codex's more restricted sandbox): **281 examples, 0 failures** --
  the 18 failures Codex reported (`Errno::EPERM`/`getifaddrs` in
  remote-fetch specs) did not reproduce here, consistent with this
  project's prior observation that this class of sandbox network
  restriction doesn't reproduce on GitHub Actions runners either
- `bundle exec rubocop`: 108 files, no offenses
- Committed `5f669af`, pushed, CI run verified green (see bundle
  report for run ID)

### Closure

`#32`'s acceptance criteria are met for the scope that's actually
Sushi-clean (`Observation`-mapped entries). `#33` tracks the
`Condition`/`component` gap as separate follow-up work, not a blocker
for closing `#32`.

---

## R3 -- Remove active_support from FshGenerator (0.6.0 task, condition 1)

Codex's `#32` delivery required `active_support/core_ext/string` for three
`String` methods (`camelize`, `humanize`, `parameterize.dasherize`),
violating the structural clause `anlage`'s `docs/design/fsh-plan.md`
already committed to (追記1, 2026-08-26): FshGenerator must depend on
`openehr` only (Rails-independent), so it can move wholesale to the
future `openehr-fhirbridge` satellite gem -- explicitly named review
criterion: no dependency on `ActiveRecord::Base` or the `Rails`
namespace. `require 'active_support/core_ext/string'` doesn't touch
either directly, but ActiveSupport is Rails-family tooling, not
`openehr`-only; the clause's spirit is what's being restored here, not a
literal `ActiveRecord::Base`/`Rails` grep hit.

Measured exact behavior before replacing anything (not guessed): ran the
three ActiveSupport methods against representative inputs directly, then
cross-checked plain-Ruby candidate replacements against every entry from
every fixture this generator is exercised against (`bmi_calculation.opt`,
`bmi_calculation_without_uid.opt`, `problem_list.opt`,
`lab_result_report_reduced.opt`) -- all matched exactly, including the
one non-obvious case: `.parameterize` alone leaves internal underscores
intact (`"OBSERVATION.body_mass_index.v2".parameterize` =>
`"observation-body_mass_index-v2"`); `.dasherize` afterward is doing real
work (not redundant), converting those to `"observation-body-mass-index-v2"`.

Replaced with three small private helpers (`camelize`, `humanize`,
`parameterize`) matching the measured behavior. Re-verified with `sushi`
after the change, not just `rspec`: `bmi_calculation.opt` still 0
Errors/0 Warnings (3 profiles), `problem_list.opt` still exactly 29
errors (unchanged `#33` gap). Full suite: 281 examples, 0 failures.
RuboCop clean. Committed directly to `master` (`0181f7f`, tiny/self-
contained per the task's own "極小コミット" framing -- no separate
issue/branch/PR, matching this repo's docs-and-tooling-adjacent-fix
precedent for changes that don't touch public API or behavior).

`ProfileGenerator` still requires `active_support/core_ext/string` --
explicitly out of scope: it isn't planned for extraction to
`openehr-fhirbridge` on its own, so the structural clause doesn't bind it.

---

## R4 -- Release inventory (v0.5.0..master) and 0.6.0 proposal (condition 3)

Classified every non-merge commit since `v0.5.0` (8 commits; per-commit
file lists pulled via `git log --name-only`, not asserted from memory):

- **Neutral (6 commits)**: `19c905f`, `0d2a8ce` (docs, #30 closeout),
  `ec019b4` (`.github/ISSUE_TEMPLATE/bug_report.md` only -- dev-tooling
  config), `f7cc0eb` (design doc + report log), `a996ef4` (report log),
  `7e8014f` (`CLAUDE.md` + report log).
- **`5f669af`** (adds `FshGenerator`): new file, new public class
  (`OpenehrRails::Fhir::FshGenerator`, public `to_fsh_files`), touches
  `lib/openehr_rails.rb` to require it. New backward-compatible public
  API surface -- **minor**.
- **`0181f7f`** (drops `active_support` from `FshGenerator`): touches
  `lib/` directly but verified byte-identical output (R3 above) -- no
  new capability, no behavior change, no public API change, no gemspec
  dependency change. Per this repo's own release convention ("a commit
  touching shipped runtime code is at minimum patch, even when its
  observable behavior is unchanged"), classified **patch**.

Overall: the range's highest-level commit dominates -- **minor**, i.e.
`v0.5.0 -> v0.6.0`. No breaking changes; `FshGenerator` is net-new so
there's no existing consumer to break. `CHANGELOG.md`'s `[Unreleased]`
content matches (Added: FshGenerator; Changed: the active_support
removal -- the latter's entry was missing and added in `4b595ca` while
preparing this inventory, since this repo's convention writes CHANGELOG
entries at merge/commit time and it had been skipped when `0181f7f`
landed).

No downstream-consumption blocker analogous to R7's anlage-FSH note is
outstanding for this release -- `anlage`'s FSH work is what's consuming
`FshGenerator` itself, and per condition 4 of this task, the immediate
next step after this release is `#33`'s own explore/plan, not a
release-gated anlage dependency.

Proceeding to version bump, CHANGELOG finalization, and tag per the
task's condition 3 -- same mechanical process as R8/R9 for `v0.5.0`,
already reused rather than re-derived.

## R5 -- v0.6.0 tagged, release.yml verified green, artifact reproducibility confirmed

Caught and fixed a missing `CHANGELOG.md` entry for `0181f7f` (the
active_support removal) while preparing the version bump -- added a
`### Changed` note (`4b595ca`), full suite re-confirmed green first.

`lib/openehr_rails/version.rb` bumped `0.5.0` -> `0.6.0`;
`CHANGELOG.md`'s `[Unreleased]` retitled `## [0.6.0] - 2026-08-26` (fresh
empty `[Unreleased]` left above). Full suite: 281 examples, 0 failures.
Full-repo RuboCop (not just the touched files): 108 files, no offenses.
`bundle exec rake release:check`: OK on the first try (tree was already
clean from the prior commit). Committed (`4080053`), pushed, annotated
tag `v0.6.0` pushed.

`release.yml` run [32915373663](https://github.com/skoba/openehr-rails/actions/runs/32915373663):
overall conclusion **success** (confirmed via the run's own `conclusion`
field), all 12 jobs green -- second consecutive fully-green tag-push run,
same as `v0.5.0`'s (R8), confirming the release-path fix (PR #28) holds
across releases, not just as a one-off.

Artifact/local-build reproducibility, same method as R8: downloaded the
run's `gem` artifact (`gh run download 32915373663 -n gem`):
`openehr-rails-0.6.0.gem`, sha256
`08cdd14ab1f3890b0c6b5f0ae0d5ca55615f0b4874ed5efb0cd4d7bda9e573ca`. Built
`pkg/openehr-rails-0.6.0.gem` locally at the same tagged commit
(`4080053`, clean tree): **identical sha256**. CI artifact and local
build byte-identical, second release in a row.

RubyGems publish is the human's step next (established operating model,
unchanged from `v0.5.0`) -- the sha256 above is what to check the
published gem against. Awaiting that confirmation, then per condition 4
of the task moving on to `#33`'s explore/plan (already directed, not a
new decision to make here) and returning to dormancy in the meantime.

## R6 -- #33 explore + design doc (condition 4)

Read the issue directly (`gh issue view 33 --json ...`, not summarized
from memory) and the current `type_map.rb`/`profile_generator.rb`/
`fsh_generator.rb` source. Confirmed independently against the FHIR R5
spec: only `Observation` has a `component` element among the five
resources `TypeMap::ENTRY_RESOURCES` maps to -- the bug is not
`EVALUATION`-specific, it affects any multi-leaf entry mapped to
`Condition`/`ServiceRequest`/`Procedure`/`Encounter` (no existing
fixture exercises the latter three multi-leaf, so only `EVALUATION` is
empirically confirmed today, but the defect applies by construction).

Found a related dead-code smell while reading `type_map.rb`:
`TypeMap.value_element(resource_type)` has a comment describing exactly
the resource-type branch `#33` needs, but its ternary returns the same
string on both branches and the method is called nowhere in `lib/`
(confirmed via `grep`) -- a stub for this exact check that was never
wired up. Recommending its removal/replacement as part of this fix
rather than leaving misleading dead code.

Checked `anlage`'s `docs/design/fsh-plan.md` directly for prior art on
this exact problem before designing from scratch -- none exists; the v1
scope only anticipated `component` slicing, never the non-Observation
resource-type mismatch.

Design doc written: `docs/design/multi-leaf-non-observation-plan.md`.
Three options considered (FHIR extension encoding / split into linked
resources / restrict-to-Observation with an explicit error);
**recommending the third** -- no unvetted FHIR-modeling decision made
unilaterally, no silent data loss, verifiable end-to-end today with the
tools already in hand (`sushi`). Two genuine judgment calls flagged for
approval rather than decided here: the option choice itself, and whether
`profiles`/`to_fsh_files` should raise through the whole batch or
skip-and-report per entry when one entry hits the restriction.

Gate: reporting to the user for approval before implementation.

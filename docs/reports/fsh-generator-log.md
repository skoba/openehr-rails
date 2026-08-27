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

## R7 -- v0.6.0 artifact re-verification after the machine migration

The old development machine was lost; this repository was re-established on a
new one and re-verified against `origin` + rubygems.org before any work
resumed (that acceptance check is recorded in `openehr-ruby`'s
`docs/reports/machine-migration-log.md` R1, commit `dd2bd88`, not here --
this repository had nothing uncommitted of its own). R5 recorded the v0.6.0
CI/local artifact match, but that report was lost with the machine, so it is
re-established here from scratch.

### Tag run

`gh run list -R skoba/openehr-rails` identifies the tag push run as the
**`Release` workflow, run `32915373663`**, `event=push`, `ref=v0.6.0`,
`headSha=40800536737b85b8b0a8b1422cbea9acfb1c7929` (the same SHA the local
`v0.6.0` tag resolves to), `conclusion=success`, 3m26s.

All **12 jobs green** (`gh run view 32915373663 --json jobs`, every step's
conclusion checked, not just the run-level rollup):

- `ci / spec` x 9 -- ruby 3.3/3.4/4.0 x rails 7_2/8_0/8_1
- `ci / demo smoke (openehr:scaffold end-to-end)`
- `ci / application template smoke test`
- `Build gem artifact` -- including `release:check` (clean tree, sibling-file
  tracking, gemspec validity) and `bundle exec rake build`

### Artifact sha256 -- initial mismatch, cause found, then exact match

`gh run download 32915373663 -R skoba/openehr-rails -n gem`:

```
08cdd14ab1f3890b0c6b5f0ae0d5ca55615f0b4874ed5efb0cd4d7bda9e573ca  openehr-rails-0.6.0.gem   (209,408 bytes)
```

This did **not** match the value `223e3b3897f85c38eaffe7ea39bd7c2acf4c5de9cab7d50fe38f754ff9d65db6`
(215,040 bytes) that the migration acceptance check reported for its local
`rake build`. Diagnosed rather than reported as a reproducibility failure:

- Unpacked both `.gem` tars. `data.tar.gz`, `metadata.gz` and
  `checksums.yaml.gz` all differ.
- Payload file lists: **175 files (CI) vs 176 (local)**. The single extra file
  is `docs/design/multi-leaf-non-observation-plan.md`, and the `metadata.gz`
  diff is the same one line.
- That file was added by `536384f` ("Docs: design plan for #33"), i.e. **after**
  the `v0.6.0` tag. `openehr-rails.gemspec:19` sets
  ``gem.files = `git ls-files`.split("\n")``, so the payload tracks whatever
  commit is checked out.

**The migration check built `master` HEAD (`89ec115`, three docs commits ahead
of the tag), not `v0.6.0`.** Rebuilt from the tag itself, in a detached
worktree so the `master` checkout was never touched
(`git -C ... worktree add --detach <scratch> v0.6.0`, HEAD `40800536`, clean
tree, `MAKEFLAGS=-j1 bundle install` then `bundle exec rake build` -- the same
two commands `release.yml` runs):

```
08cdd14ab1f3890b0c6b5f0ae0d5ca55615f0b4874ed5efb0cd4d7bda9e573ca  pkg/openehr-rails-0.6.0.gem   (209,408 bytes)
```

**Byte-identical to the CI artifact.** The worktree was removed afterwards
(`git worktree remove --force`); `git worktree list` shows only the main
checkout and the tree is clean.

So `223e3b38...` is not a competing value for `v0.6.0` at all -- it is the
sha256 of a `master`-HEAD build, and there is nothing to arbitrate. The
reproducible-build property holds, and this run strengthens it: it now holds
**across machines** (old machine's R5, new machine here) and across
**ruby 4.0.6 local vs CI's `ruby/setup-ruby@v1` ruby 4.0**, on the same commit.
The build is commit-sensitive, not machine-sensitive -- which is the property
that actually matters for release verification.

**RubyGems publish is unblocked** (human's step, per the established operating
model). `gem list -r -a openehr-rails` confirms the published latest is still
`0.5.0`. The value to check the published `0.6.0` gem against is
`08cdd14ab1f3890b0c6b5f0ae0d5ca55615f0b4874ed5efb0cd4d7bda9e573ca`.

### Convention: cross-repo authorization gate

The line directed for this batch -- implementation target outside this
repository means a gate report before starting, and `cd`/`-C`/`-R` discipline
does not substitute for authorization to cross -- was already added to **this**
repository's `CLAUDE.md` on 2026-08-26 (section "Cross-repository
implementation work needs its own authorization gate", `CLAUDE.md:105-124`).
Re-adding it here would only duplicate it, so it was not touched.

That entry noted a matching line was still planned elsewhere. `openehr-ruby`'s
`CLAUDE.md` was confirmed to lack it (its "Repository boundary" and
"Repository-context-dependent commands" bullets cover the *how*, not the
*whether*), so the rule was mirrored into `openehr-ruby`'s Contribution
workflow section there. `anlage`'s `CLAUDE.md` still lacks it -- writing to
`anlage` is itself a crossing this rule gates, so it was not done without a
direction naming that repository.

### Gate

`#33` (`docs/design/multi-leaf-non-observation-plan.md`) remains at the
approval gate opened in R6. No implementation started; standing by for the
arbitration.

## R8 -- 0.6.0 RubyGems publish: confirmed, but not the CI-verified artifact

The human published `openehr-rails 0.6.0` to RubyGems. `gem list -r -a
openehr-rails` now shows `0.6.0` as the published latest. Verified the
published artifact rather than assuming it -- and it is **not** the gem R7
told them to check against.

### Measurements

`gem fetch openehr-rails -v 0.6.0 --source https://rubygems.org`:

```
223e3b3897f85c38eaffe7ea39bd7c2acf4c5de9cab7d50fe38f754ff9d65db6   215,040 bytes
```

- R7's expected value (CI artifact from run `32915373663`, reproduced
  byte-identically from the `v0.6.0` tag):
  `08cdd14ab1f3890b0c6b5f0ae0d5ca55615f0b4874ed5efb0cd4d7bda9e573ca`,
  209,408 bytes -- **does not match**.
- `cmp` against `pkg/openehr-rails-0.6.0.gem` left in this repo's working
  tree: **byte-identical**. That file was built during the machine-migration
  acceptance check, from `master` HEAD (`89ec115`), three docs commits past
  the tag. Its sha256 was reported in that check as if it were the v0.6.0
  build; it is the file that got published.

### What actually differs

Unpacked both `data.tar.gz` payloads and diffed recursively (`diff -rq`).
The **entire** delta is two documentation files:

- added: `docs/design/multi-leaf-non-observation-plan.md` (the `#33` design
  doc, commit `536384f`)
- changed: `docs/reports/fsh-generator-log.md` -- this log, carrying R6

`diff -rq` over the whole `lib/` subtree reports **no differences**: the
shipped runtime code is byte-identical to the CI-verified artifact. The
`metadata.gz` diff is the single extra `files` entry; version, runtime
dependencies and `required_ruby_version` are unchanged.

So the published gem is **functionally identical** to what CI built and
verified at the tag. The extra content is newer in-repo documentation, not
stale or foreign code.

### Root cause and the convention gap it exposes

`gem.files` comes from `git ls-files` (`openehr-rails.gemspec:19`), so a
build is only a *release* build if HEAD is at the release tag.
`release:check` (`lib/openehr_rails/release_check.rb`) guards a clean working
tree, sibling-file tracking, and gemspec validity -- **it does not assert
that HEAD is at `v<version>`**. Nothing in the release path catches a gem
built from a commit past the tag, and a stale `pkg/*.gem` from an unrelated
local build is publishable by hand without any check firing.

Two follow-ups proposed, neither started (this repo is ticket-driven and
`#33` is still the standing gate):

1. `release:check` should fail when `version.rb`'s version has a tag in the
   repo and HEAD is not that tag. This touches `lib/`, so it is at minimum a
   patch under the Release convention and needs its own Issue.
2. `rake build` output is a release candidate only under that condition;
   until then, publishing should come from the CI artifact, not a local
   `pkg/` file.

Removed the stale `pkg/openehr-rails-0.6.0.gem` from the working tree
(untracked, `.gitignore`d) so it cannot be picked up again; the identical
bytes are now on rubygems.org, which is the record.

### Open decision (human's)

Whether to accept the published 0.6.0 as-is or yank and re-release. Note
RubyGems does not permit re-pushing a yanked version number, so yanking means
`0.6.1`. Recommendation: **accept**. There is no runtime, dependency or
license delta -- only two docs files, both newer than the tag -- and a
version bump would spend a release number to remove documentation from a
gem. The value of record for published `0.6.0` is therefore
`223e3b3897f85c38eaffe7ea39bd7c2acf4c5de9cab7d50fe38f754ff9d65db6`, with
`08cdd14a...` recorded here as the tag-build value it diverges from.

`#33` remains at its approval gate; nothing implemented.

## R9 -- 0.6.0 incident ruling applied (accept + two preventions)

Ruling: accept 0.6.0 rather than yank, and land both preventions -- the
operational one first, the code one behind an Issue. All four items done,
one commit each.

### 1. Accept, with a transparency note (`899fa4c`)

`CHANGELOG.md`'s `[0.6.0]` section now carries a blockquote stating that the
published gem is the tagged tree plus two documentation files, that `lib/` is
byte-identical and version/dependencies/`required_ruby_version` unchanged, and
both sha256 values (`223e3b38...` published, `08cdd14a...` tag build), pointing
at R8 for the measurements. No yank; `0.6.0` stands.

### 2. Operational prevention first (`9e9f628`)

`CLAUDE.md`'s "Release convention" section gained a **Publish only the CI
artifact itself** rule: `gem push` takes the `.gem` from
`gh run download <run-id> -n gem`, after sha256 comparison against that run's
recorded value -- never a locally built `pkg/*.gem`. The rationale names the
mechanism (`gem.files` from `git ls-files`) and the trap (a stale `pkg/`
artifact is indistinguishable by filename from a release build).

### 3. Code prevention behind an Issue (`7b68d7b`, Fixes #34)

Filed `skoba/openehr-rails#34` (bug) with R8 as evidence and spec-verifiable
acceptance criteria, then implemented t-wada style.

**Red first**: three examples added to
`spec/openehr_rails/release_check_spec.rb` -- HEAD past the tag flags,
HEAD exactly at the tag passes, and no matching tag contributes nothing. Run
before the implementation: **7 examples, 1 failure**,
`expected "" to match /v0\.1\.0/`.

**Green**: `ReleaseCheck#release_tag_failures` compares
`rev-parse HEAD` against `rev-parse v<version>^{commit}`, guarded by a
non-raising `git?` ref-existence probe so an untagged version stays silent
(ordinary pre-release development). `gemspec_path`/`spec` were memoised so the
new check reuses the already-loaded gemspec rather than parsing it twice.
Re-run: **7 examples, 0 failures**.

**Verified against the real incident**, not only the fixture repo -- on
`master` (`v0.6.0` tagged, HEAD `6bbdf51`) the task now aborts with:

```
release:check FAILED: HEAD (6bbdf51) is not the v0.6.0 tag commit (4080053) --
a gem built here would not match the released artifact for that version;
build from v0.6.0 itself, or publish CI's tag-run artifact
```

Blast radius checked before accepting that behaviour: `release:check` runs
only in `release.yml`'s tag-triggered `build` job and by hand before a release
-- `Rakefile`'s default task is `:spec`, and `ci.yml` runs `rake spec` /
`rspec` only -- so failing between releases is the intended signal, not noise
in everyday development.

`bundle exec rspec`: **284 examples, 0 failures** (281 before, +3 new).
`rubocop` on both changed files: no offenses. Semver **patch** and a
`[Unreleased]` CHANGELOG entry: `ReleaseCheck` ships in the gem but is a
release-time dev tool not required by `lib/openehr_rails.rb`, so no host-app
runtime or public-API change -- yet it touches `lib/`, so not neutral. Rides
along with the next release; no standalone release for it.

### 4. Backlog evidence line (`829275f`)

`docs/backlog.md`'s Trusted Publishing item gained a sub-bullet recording the
cross-machine reproducibility evidence in its favour.

**Correction to the directive's SHA**: the ruling cited `89ec115` as the
commit demonstrating machine- and Ruby-version-crossing byte-identity. Checked
against R7/R8 rather than transcribed: `89ec115` is `master` HEAD, whose build
(`223e3b38...`) exists only from this machine -- it demonstrates nothing about
crossing machines. The commit that does is **`4080053`** (the `v0.6.0` tag),
which produced `08cdd14a...` from CI, from the old machine (R5), and from a
rebuild here under local ruby 4.0.6 vs CI's `ruby/setup-ruby@v1` ruby 4.0. The
backlog line records `4080053`.

### Gate

Back to standby. `#33`
(`docs/design/multi-leaf-non-observation-plan.md`) is unchanged and still at
its approval gate; nothing implemented against it.

## R10 -- #33 implemented: EVALUATION -> Condition proper mapping

Ruling 2026-08-27 adopted **option (d), proper mapping** over this repo's own
design doc, which had recommended option (c) (restrict + raise). All five
`problem_diagnosis` leaves land on real `Condition` elements.

### Mapping table fixed before implementation (`07767cc`)

`docs/design/multi-leaf-non-observation-plan.md` gained section 8 as the
normative spec; sections 2-6 kept for the record, marked superseded. One
rationale line per element, and the deliberate omissions stated with reasons.

Measured, not assumed, before a line was written: leaves are
`FieldExtractor#entries` for `spec/templates/problem_list.opt`, and the exact
rule set the implementation would have to emit was compiled against
`hl7.fhir.r5.core#5.0.0` with `sushi` 3.16.0 -- **0 Errors** -- so the design was
known to be valid FHIR before it was a design.

| leaf | -> `Condition` |
|---|---|
| *(anchor)* | `category` (fixed CKM coding) |
| `at0002` プロブレム・診断名 | `code`, bound to ICD-11 MMS (required) |
| `at0077` 発症日時 | `onsetDateTime` |
| `at0003` 臨床的に認識された日時 | `recordedDate` (approximation, recorded as such in 8.1) |
| `at0030` 治癒日時 | `abatementDateTime` |
| `at0073` 診断確度 | `verificationStatus`, **no binding emitted** |

The anchor had to move off `code`: under a proper mapping `code` is the
diagnosis (at0002), not the archetype id.

### TDD

**Red**: generated FSH for `problem_list.opt` compiled to **29 Errors** (all
`No element found at path component…`) -- the pin. Specs added first: golden
byte-match plus four behavioural examples in `fsh_generator_spec.rb`, five in
`profile_generator_spec.rb`. Before implementation: **10 failures**
(11 examples/5 failures and 16/5 respectively).

**Green**: `39 examples, 0 failures` across `spec/openehr_rails/fhir/`.
Generated FSH byte-matches the golden and compiles to **0 Errors** under `sushi`
3.16.0 -- verified on the real generator output, not a hand-written sample, for
`problem_list.opt` *and* `bmi_calculation.opt` together (the `Observation`
`component` regression pin still compiles).

### Implementation

`TypeMap::ENTRY_ELEMENT_MAPS`, keyed by archetype id, next to `ENTRY_RESOURCES`
-- the existing mechanism, per the ruling, rather than new conditionals in two
places. Both generators ask `TypeMap` for the map and take one extra branch
each; `TypeMap.value_set_canonical` centralises the `terminology:` strip that
only `FshGenerator` did before, so the two outputs cannot disagree on a
canonical. The dead `TypeMap.value_element` was removed as the design doc
proposed (its intended resource-type branch is now the table).

### Three pre-existing pins updated, and coverage genuinely lost

`problem_list.opt` is this repo's **only** fixture with a local `code_list` or a
`C_CODE_REFERENCE` value set (checked across every fixture, not assumed), so
changing its output moved the only ground under three `#30`-era specs:

1. `profile_generator_spec.rb` "emits a required value-set binding" -- intent
   intact (at0002's empty `code_list` still does not suppress the binding); the
   element is now `Condition.code` and the canonical no longer carries the
   `terminology:` prefix.
2. `fsh_generator_spec.rb` "emits a required binding" -- same, now asserting
   `* code from … (required)`.
3. `profile_generator_spec.rb` "keeps a local code-list binding free of a
   valueSet" -- **this pin's premise is gone**. at0073 now maps to
   `verificationStatus`, which emits *no* binding, not a strength-only one.
   Replaced with a pin on the new truth.

**Consequence recorded rather than papered over**: `ProfileGenerator#apply_value_constraints`'
strength-only `DV_CODED_TEXT` branch, and its `terminology:`-prefixed `valueSet`
on the legacy single-leaf path, now have **no fixture exercising them**. Both
still ship for any archetype not in the mapping table. The prefixed canonical in
particular looks like a latent bug -- a FHIR `valueSet` should be the canonical
itself, which is why `FshGenerator` always stripped it -- but fixing it is
outside #33's ruling and would need its own Issue and a fixture that reaches
that path.

### Scope boundary

Generalisation to other `EVALUATION` archetypes was explicitly not required.
`INSTRUCTION`→`ServiceRequest` (`request-referral`, arriving with referral v2)
is reserved as **#35**, filed but not scheduled -- it is blocked on a real
fixture, since `anlage` recommended against taking `mml_referral.opt` in.

### Semver

**Minor**, and `CHANGELOG.md` says "breaking for consumers of generated FHIR
profiles" plainly: the JSON facade's shape changes for `EVALUATION` entries and
host apps must regenerate `app/fhir/profiles/*.json`. Rides with #34's
`release:check` change; 0.7.0 expected, finalised at release inventory.

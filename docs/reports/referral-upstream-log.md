# Referral-v2 upstream batch log (anlage candidates 15-17 and siblings)

Work on `openehr-rails` driven by `skoba/anlage`'s `jp_referral` v0.1 findings
(`docs/upstream-candidates.md` items 15-17, 2026-09-25). R1〜.

---

## R1 -- filing, #44 fixed, #45 planned, #46-#49 filed (2026-09-25)

### State on waking

`master` = `6b0e357` (v0.7.0 + R14/R15 docs). PR #43 (#38, 0.7.1) still open and
unmerged since 2026-09-10, CI green. Open issues before this batch: #35-#38.

### 1. #44 -- AQL store-wide failure isolated per composition (PR #50)

- Measured cause: `DatasetAdapter` materialises every head composition with
  `to_rm` inside the lazy chain (`dataset_adapter.rb:35,37`); `RmObjectBuilder#build_node`
  did `TYPE_CLASSES[rm_type]` -> nil -> `NoMethodError` for SECTION / INSTRUCTION /
  ACTIVITY / ACTION / ITEM_SINGLE / ITEM_TABLE, all of which `GraphBuilder`
  persists (`Rm::TypeMap::NODE_TYPES`).
- Resolution shape (a) bug. **Red**: 23 examples, 3 failures (DatasetAdapter walk,
  Executor end to end, `to_rm` directly) against a synthetic SECTION composition
  committed beside a BmiCalculation record. **Green**: 23/0, full suite **307/0**
  (304 + 3), rubocop clean (one extraction, `node_class`, to stay under
  `build_node`'s AbcSize/complexity limits).
- Behaviour: `DatasetAdapter#materialize` rescues, reports through `Rails.logger`
  when present else `Kernel#warn` (spec env has no `Rails.logger`, so the specs
  pin stderr), skips the composition. `OpenehrRails::Rm::UnsupportedRmTypeError`
  (composition_uid, rm_type, path) replaces the accidental `NoMethodError`.
- PR #50 (`dd157b6`, Fixes #44), CI run 36115865528. Semver patch; CHANGELOG
  `[Unreleased]` Fixed.

### 2. #45 -- SECTION / INSTRUCTION / ACTIVITY on the read side: explore + plan

`docs/design/rm-object-builder-section-instruction-plan.md`. Verdict: **small**
(phase A: 3 map entries, helper methods in one file, ~130 spec lines, no schema
change) -> recommended before the freeze, awaiting approval. Phase B (persist
`action_archetype_id`, ACTION, ITEM_SINGLE/TABLE) December. Note: minor, so a
release carrying it is 0.8.0.

### 3. Filed only

- **#46** context (EVENT_CONTEXT) not persisted from canonical JSON (upstream 16).
- **#47** FieldExtractor does not descend `activities` / `description` / `protocol`
  (upstream 17; `DESCENDABLE_ATTRIBUTES = %w[data events items value]`,
  `field_extractor.rb:47`).
- **#48** DV_TEXT leaf on a CodeableConcept target -> `code only string` (invalid);
  mapping row should carry the FHIR type.
- **#49** 0-leaf entry gets an empty component-header profile instead of
  skip-and-report (#38 sibling; #43 covers non-Observation 0-leaf once merged,
  Observation 0-leaf not).

### 4. 0.7.1 inventory (candidates, not yet a gate)

| item | state | class |
|---|---|---|
| PR #43 (#38 single-leaf skip) | open, CI green, rebased on 0.7.0 | patch |
| PR #50 (#44 isolation) | open, CI running | patch |
| #45 phase A | plan awaiting approval | minor -> 0.8.0 |
| #46 / #47 / #48 / #49 | filed | -- |

Gate when the human has merged what should ride; version number decided from the
merged content (0.7.1 if patch-only, 0.8.0 if #45 rides).

## R2 -- 0.7.1 gate approved and tagged; artifact sha256 differs from the tag rebuild by the rubygems stamp only (2026-09-25)

### Gate (approved by the 統括, 2026-09-25)

`master` `df93c71` (= #43 + #50 merged): `lib/` touched by `5fcc0ec` (#38) and
`dd157b6` (#44), both bug fixes -> **patch**; gemspec / version / dependencies
unchanged; everything else docs. **0.7.1**, #45 deliberately excluded (minor ->
0.8.0 later, its own inventory). CHANGELOG plan adopted with one addition asked
for by the ruling: a one-line Upgrade note that AQL now warns and skips instead
of failing every query, quoting the log line
`openehr-rails AQL: skipping composition uid=...` so an operator can find it.

### Release

- `ceb4c5b` Release: bump version to 0.7.1 (`version.rb`, `[0.7.1] - 2026-09-25`
  with the Upgrade note, fresh empty `[Unreleased]`). Before it: full suite
  **311 examples, 0 failures**, rubocop **no offenses**, `release:check OK`;
  `master` CI run 36128248178 success.
- Tag `v0.7.1` -> `ceb4c5b`, **annotated** this time (`git tag -a`, the R14
  correction applied).
- `release.yml` run **36128715938**: 12 jobs success, `release:check OK` at the
  tag. Artifact `pkg/openehr-rails-0.7.1.gem`, 251904 bytes,
  sha256 **`29e89993894fe974a1f7eb1cbd51b1809c67aadd1cd5917f4b01af8142159784`**.
  upload-artifact archive digest (not the gem): `216aff34…7c9a`.

### The rebuild cross-check did not match, and why that is fine

A `gem build` in a scratch worktree at `v0.7.1` (local ruby 4.0.6, rubygems
4.0.16) gave sha256 `fd06e784…4f8a`, **not** the artifact's. Taken apart
(`tar xf`; the .gem is a tar of `metadata.gz`, `data.tar.gz`, `checksums.yaml.gz`):

| part | CI artifact | local rebuild |
|---|---|---|
| `data.tar.gz` (the shipped files) | `b54d9259…` | `b54d9259…` **identical** |
| `metadata.gz` | differs on one line: `rubygems_version: 4.0.20` (CI ruby 4.0.7) | `rubygems_version: 4.0.16` |
| `checksums.yaml.gz` | differs (it hashes metadata) | -- |

So the bytes host apps load are identical; only rubygems' own version stamp
moved, because `ruby/setup-ruby`'s ruby 4.0 image advanced from 4.0.6 to 4.0.7
since 0.7.0 (when both sides happened to run rubygems 4.0.16 and the whole-gem
sha256 matched). **Lesson, recorded in `docs/backlog.md`**: the rebuild
cross-check must compare `data.tar.gz` (and `metadata.gz` minus
`rubygems_version`), not the whole `.gem`; a whole-gem match is a coincidence of
equal toolchains. The "Record sha256" CI step in the backlog stays the real pin
for the published bytes.

### Handed to the human

`gem push pkg/openehr-rails-0.7.1.gem` (the downloaded CI artifact), then confirm
`https://rubygems.org/api/v1/gems/openehr-rails.json` `sha` == `29e89993…9784`
(compact index `checksum:` likewise), then delete the file from `pkg/`. Result
-> R3. `master` is past the tag by these docs commits (`release:check` on
`master` fails by design).

### Pending

#45: the ruling's "conditions a-c" (pre-freeze implementation approved, 0.8.0)
have not reached this session as text; implementation starts once they do.

## R3 -- 0.7.1 published; confirmed by checksum (2026-09-25)

Human `gem push` of the CI artifact (R2). Confirmation against the artifact's
sha256 `29e89993894fe974a1f7eb1cbd51b1809c67aadd1cd5917f4b01af8142159784`:

| source | value |
|---|---|
| `/api/v1/gems/openehr-rails.json` | version 0.7.1, `sha` `29e89993…9784` |
| compact index `info/openehr-rails` | `0.7.1 … checksum:29e89993…9784, created_at:2026-09-25T11:43:12Z` |
| `/api/v1/versions/openehr-rails/latest.json` | `{"version":"0.7.1"}` |
| `/api/v1/versions/openehr-rails.json` | **still 0.7.0 first** at check time -- the propagation lag CLAUDE.md warns about, observed for real this time |

Published gem == CI artifact. `pkg/` emptied. The judgement rule from R2 (tag
rebuild: `data.tar.gz` identical, metadata differs by `rubygems_version` only)
stands as the cross-check for future releases.

Next: #45 phase A implementation per the ruling (conditions a-c), PR `Fixes #45`,
then the 0.8.0 inventory.

## R4 -- #45 phase A implemented (PR #51), ride-alongs #52 (PR #53) and #49 (PR #54) (2026-09-25)

Ruling: #45 phase A approved for pre-freeze implementation with conditions (a)
injected defaults stated as approximations, (b) regression pin on the existing
fixtures and the anlage demo queries, (c) #44's SECTION fixture -> ITEM_TABLE;
ride-alongs to weigh: anlage upstream 19 (`rm_type_alternatives`) and #49.

### PR #51 -- `feat/45-rm-object-builder-section-instruction` (Fixes #45)

- (b) enhancement. **Red**: 8 new examples on a synthetic canonical hash
  (`spec/support/synthetic_referral_canonical_hash.rb`: SECTION > EVALUATION;
  INSTRUCTION with narrative, protocol ITEM_TREE, one ACTIVITY with description
  and DV_PARSABLE timing) -> `UnsupportedRmTypeError` / empty AQL rows.
  **Green**: 36/0 in the four touched spec files, full suite **324 examples,
  0 failures**, rubocop clean (after one lint follow-up commit for the spec
  file name).
- `TYPE_CLASSES` += SECTION, INSTRUCTION, ACTIVITY; `build_node` split into
  one helper per stored type (`entry_attributes`, `section_attributes`,
  `instruction_attributes`, `activity_attributes`, `history_attributes`,
  `event_attributes`, `element_attributes`); every CARE_ENTRY gets `protocol`
  when stored. Constructor probes against openehr 2.4.3 before coding:
  `Section.new(items: nil)` ok, `Activity.new(description:, action_archetype_id:)`
  ok with `timing` nil, `DvParsable.new(value:, formalism:)` ok.
- AQL measured through the new objects: `i/activities[at0001]/description[at0009]/items[at0121]/value/value`,
  `i/protocol[at0008]/items[at0010]/value/value`, and an EVALUATION nested in a
  SECTION via `CONTAINS EVALUATION ev[...]` -- all return the stored values.
  (`CONTAINS SECTION s[...]` as a hop was not needed and not pinned.)
- (a): `narrative` <- node name when no row; `action_archetype_id` <- `'/.*/'`
  -- stated in the class comment, at the injection sites, in the specs and in
  CHANGELOG `[Unreleased]` Added, as approximations pending phase B.
- (b): `spec/openehr_rails/aql/executor_execute_demo_queries_spec.rb` pins the
  four anlage demo queries (bmi_calculation graph + a synthetic
  problem_diagnosis composition with the real at-codes). Measured on the way:
  a naive `DV_DATE_TIME` value committed as `2026-02-01T00:00:00` comes back
  as `2026-01-31T15:00:00Z` under JST -- the pin compares instants, not
  strings (pre-existing behaviour, not touched). `protocol` nil pinned on an
  OBSERVATION without one.
- (c): the #44 fixtures in `dataset_adapter_spec` / `executor_spec` /
  `rm_object_builder_spec` now use an ITEM_TABLE as an EVALUATION's data.
- CI runs 36131797849 (`ca1af81`) and 36132042465 (`368da91`, lint follow-up):
  success. Semver minor -> 0.8.0.

### PR #53 -- `feat/52-rm-type-alternatives` (Fixes #52, filed for upstream 19)

Small, so it rides. (b) enhancement: **red** 9/3 (key absent) -> **green** 9/0,
full suite 314/0. `FieldExtractor` fields gain `rm_type_alternatives` (the
value's child constraint types in OPT order), `rm_type` selection untouched.
**Measured before the spec**: at0002 `[DV_TEXT, DV_CODED_TEXT]`, at0073
`[DV_CODED_TEXT, DV_TEXT]` -- anlage's issue33-plan says at0073 is coded-only;
the fixture disagrees, and the spec pins the fixture. CI 36132700126 success.

### PR #54 -- `fix/49-zero-leaf-skip` (Fixes #49)

Small, same decision point as #38, so it rides. (a) bug: **red** 44/4 (a
0-leaf OBSERVATION and a 0-leaf INSTRUCTION each got a profile with an empty
`component` slicing header) -> **green** 44/0, full suite 315/0.
`TypeMap.assert_supported!` raises first for `fields.empty?`;
`UnsupportedProfileError` says "the entry has no leaves" (pointing at #47).
Built in a git worktree beside the main checkout (removed afterwards) so #52
and #49 could proceed in parallel. CI 36132843280 success.

### Merge notes for the human

All three PRs are CI-green and `MERGEABLE CLEAN` against `560647a`, but each
adds to the same `[Unreleased]` section of `CHANGELOG.md`, so after the first
merge the other two will show as conflicting; this session resolves each by
taking `master`'s CHANGELOG and re-adding the PR's bullet (as done for #43/#50),
then re-runs CI. Any order works. Then the 0.8.0 inventory (R5).

## R5 -- #53 and #54 merged into #51's branch; `release.yml` "Record sha256" rides along; CI green (2026-10-12)

Instruction: fold the two ride-alongs into #51 the way #41 was folded into #39
/ #42 (branch-into-branch merge, identical commit objects), so the human merges
one PR; then the 0.8.0 inventory.

### Branch `feat/45-rm-object-builder-section-instruction` (PR #51), now

| commit | what |
|---|---|
| `ae71034` | Merge branch `feat/52-rm-type-alternatives` (#53, `d574358`) |
| `e180eef` | Merge branch `fix/49-zero-leaf-skip` (#54, `7d4d203`) |
| `1410274` | CI: `release.yml` gains `Record sha256` (`sha256sum pkg/*.gem \| tee pkg/SHA256SUMS`) after `rake build`, ported back from openehr-ruby's copy; `docs/backlog.md` "Release automation" item. CI-only, no Issue (the backlog's own call); rides here so one merge lands it ahead of the `v0.8.0` tag run, which is the first run that will print it. |

- Code files were disjoint; the only conflict in both merges was
  `CHANGELOG.md` `[Unreleased]` (as R4 predicted). Resolution: #45's and #52's
  bullets kept in that order under one `### Added`; #49's bullet under a
  `### Fixed` below. `git diff origin/master...HEAD`: 14 files, the union of
  the three PRs' diffs plus `release.yml`.
- Local, after the merges (bundle had to be installed first -- this checkout
  had no gems): **331 examples, 0 failures**; rubocop **no offenses**
  (111 files).
- CI: run **38216664617** (`e180eef`, the two merges) success; run
  **38216762262** (`1410274`, final head) **success, 11/11 jobs**. PR #51
  `MERGEABLE CLEAN` against `master` `0434e06`.
- PR #51's body now names the ride-alongs with `Fixes #52` / `Fixes #49`, so
  the one merge closes #45, #52 and #49.

### Handed to the human

Merge #51 with a **merge commit** (not squash): then `d574358` and `7d4d203`
become reachable from `master` as the same objects #53 / #54 point at, exactly
the #41 situation. After the merge this session comments on #53 and #54
("taken in via #51") and closes them if GitHub has not already, then runs the
0.8.0 inventory (`v0.7.1..master`) as a gate report (R6).

Inventory preview, measured on the branch (the gate itself waits for the
merge): `lib/` touched by `rm_object_builder.rb` (#45, enhancement),
`opt/field_extractor.rb` (#52, additive output), `fhir/type_map.rb` +
`fhir/unsupported_profile_error.rb` (#49, bug); gemspec / version /
dependencies untouched; `release.yml` and the docs commits neutral. Expected
call: **minor -> 0.8.0**, as #45's plan said.

## R6 -- #51 merged (with #53/#54 inside); 0.8.0 inventory and gate (2026-10-12)

### Step 0: measured on `master` `1185c07` (the #51 merge commit)

- `lib/openehr_rails/rm/rm_object_builder.rb:48-53` `TYPE_CLASSES` has
  `SECTION`, `INSTRUCTION`, `ACTIVITY` (#45);
  `lib/openehr_rails/opt/field_extractor.rb:167` emits `rm_type_alternatives`
  (#52); `lib/openehr_rails/fhir/type_map.rb:29` raises first on
  `fields.empty?` (#49); `.github/workflows/release.yml:29-30` has the
  `Record sha256` step.
- `CHANGELOG.md` `[Unreleased]`: `### Added` with the #45 and #52 bullets,
  `### Fixed` with the #49 bullet -- the R5 resolution survived the merge.
- #51 merged 13:37 UTC as a merge commit; GitHub marked #53 (`ae71034`) and
  #54 (`e180eef`) merged by reachability, #45/#52/#49 closed. Both PRs got a
  "taken in via #51" comment.
- `master` CI run **38256998466** (`1185c07`) success. Local under ruby
  4.0.7: **331 examples, 0 failures**, rubocop no offenses (111 files).
  `release:check` on `master` fails by design (HEAD is past the `v0.7.1` tag).
- #55 (FHIR profile id collision, anlage ledger 23): open issue, no PR,
  nothing in `v0.7.1..master` references it -- stays out, December.

### Step 1: inventory `v0.7.1..master`

| commit | touches | class |
|---|---|---|
| `b403226` `560647a` `0434e06` `84244cd` | docs/reports, docs/backlog | neutral |
| `32a79e7` `29a1444` | `.ruby-version`, CLAUDE.md | neutral (dev env / docs) |
| `1185c07` = #51: `ca1af81` | `rm/rm_object_builder.rb` + specs (#45, enhancement) | **minor** |
| -- `368da91` | spec file rename | neutral |
| -- `ae71034` <- `d574358` | `opt/field_extractor.rb` (#52, additive output) | minor |
| -- `e180eef` <- `7d4d203` | `fhir/type_map.rb`, `fhir/unsupported_profile_error.rb` (#49, bug) | patch |
| -- `1410274` | `release.yml` Record sha256 | neutral (CI) |

Gemspec, `version.rb`, `Gemfile`, `gemfiles/*` untouched. Highest class is
minor -> **0.8.0**, matching the instructed number.

### Prepared, uncommitted, for the release commit

`CHANGELOG.md`: `[Unreleased]` -> `[0.8.0] - 2026-10-12` with an Upgrade note
(two points: SECTION/INSTRUCTION compositions now read back through `to_rm`
and AQL -- the ones 0.7.1 skipped with the warning are the ones that become
visible; `narrative` / `action_archetype_id` injected defaults are
approximations until phase B persists them), the three bullets unchanged, a
fresh empty `[Unreleased]` above. `version.rb` 0.7.1 -> 0.8.0 goes in the
same commit (`ceb4c5b`'s shape). Tag `v0.8.0` annotated; the Release run
prints the gem's sha256 in `Record sha256`, which is the value the human's
publish and the post-publish checksum are compared against; the tag-rebuild
cross-check judges by `data.tar.gz` (R2 rule).

## R7 -- v0.8.0 tagged; Release run 38258179628 green; Record sha256's first real run matches artifact and local rebuild byte for byte (2026-10-12)

Gate approved by the 統括 (2026-10-12): minor -> 0.8.0, Upgrade note's two
points accepted as written.

- `425453d` Release: bump version to 0.8.0 (`version.rb`, `[0.8.0] -
  2026-10-12` with the Upgrade note, fresh empty `[Unreleased]`). Before it:
  **331 examples, 0 failures**, rubocop no offenses.
- Tag `v0.8.0` -> `425453d`, annotated. `master` and the tag pushed.
- `release.yml` run **38258179628**: 12 jobs success, `release:check OK` at
  the tag. **`Record sha256` (first run of the step, `1410274`) printed
  `d9068d3ed4252fd33f0cfb4e25506118787235ae7d8ade203a7063087e5c7aa6
  pkg/openehr-rails-0.8.0.gem`.**
- Downloaded artifact (`gh run download 38258179628 -n gem`): 263680 bytes,
  sha256 **`d9068d3e…c7aa6`** == the value the run printed.

### Cross-check against a tag rebuild (R2 rule)

Scratch worktree at `v0.8.0`, local ruby 4.0.7 / rubygems 4.0.20 (the 4.0.7
pin from `32a79e7`):

| part | CI artifact | local rebuild |
|---|---|---|
| whole `.gem` | `d9068d3e…c7aa6` | `d9068d3e…c7aa6` **identical** |
| `data.tar.gz` | `180145cf…6108e` | `180145cf…6108e` **identical** |
| `metadata.gz` | `a30bd4a5…397e83`, `rubygems_version: 4.0.20` | same |

The whole-gem match is back because both sides now run rubygems 4.0.20 --
the parity the 4.0.7 pin was for. The judgement rule stays `data.tar.gz`
(identical) plus `metadata.gz` minus `rubygems_version`; the whole-gem
equality is confirmation, not the criterion.

### Handed to the human

`gem push pkg/openehr-rails-0.8.0.gem` -- the file in `pkg/` is the downloaded
CI artifact (sha256 above; `pkg/` is git-ignored), not a local build. After
the push this session confirms `https://rubygems.org/api/v1/gems/openehr-rails.json`
`sha` and the compact index `checksum:` == `d9068d3e…c7aa6`, then empties
`pkg/` -> R8. `master` is past the tag by this docs commit, so
`release:check` on `master` fails by design again.

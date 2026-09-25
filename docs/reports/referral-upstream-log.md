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

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

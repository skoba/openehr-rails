# Plan: `RmObjectBuilder` reads back SECTION / INSTRUCTION / ACTIVITY

- Status: **explore + plan, awaiting approval** (2026-09-25). No code written.
- Issue: [#45](https://github.com/skoba/openehr-rails/issues/45) (anlage upstream candidate 15)
- Log: `docs/reports/referral-upstream-log.md` R1
- Prerequisite landed as its own fix: #44 / PR #50 (a failing `to_rm` no longer
  fails the whole store; unknown types raise `UnsupportedRmTypeError`).

## 1. Current behaviour (measured, `file:line` on `master` after PR #50)

**Write side accepts the types.** `Rm::TypeMap::NODE_TYPES`
(`lib/openehr_rails/rm/type_map.rb:9-26`) lists SECTION, INSTRUCTION, ACTION,
ACTIVITY (and ITEM_SINGLE, ITEM_TABLE); the STI classes exist
(`lib/openehr_rails/rm/nodes.rb:10,14,15,18`). `GraphBuilder#infer_type`
(`lib/openehr_rails/rm/graph_builder.rb:111-122`) maps `activities` -> ACTIVITY and
`protocol` / `description` -> ITEM_TREE for `_type`-less hashes. `build_children`
(`:64-79`) persists Hash-valued attributes as child nodes or data-value rows and
Array-valued ones as ordered children; **String-valued attributes are dropped** --
so `ACTIVITY.action_archetype_id` never reaches the graph. `INSTRUCTION.narrative`
(DV_TEXT), `ACTIVITY.timing` (DV_PARSABLE: `text_value` + `formalism`, `:180-181`)
and `INSTRUCTION.expiry_time` (DV_DATE_TIME) are stored as data-value rows keyed by
`rm_attribute_name`.

**Read side does not.** `RmObjectBuilder::TYPE_CLASSES`
(`lib/openehr_rails/rm/rm_object_builder.rb`, 10 entries) has none of them;
`build_node` sets entry defaults only for Observation / Evaluation / AdminEntry,
`data` only for `EntryNode`, and never `protocol`, `narrative`, `activities`,
`description`. After PR #50 such a node raises `UnsupportedRmTypeError` and the
composition is skipped from AQL with a warning; before it, the whole store failed
(anlage referral-intake-log R6).

**What the openehr gem (2.4.3) demands of the objects** (`openehr-ruby`
`lib/openehr/rm/composition/content/`):

| class | mandatory | optional / notes |
|---|---|---|
| `Navigation::Section` (`navigation.rb:12-27`) | -- | `items` must be nil or non-empty; `path_attribute :items` |
| `Entry::Instruction` (`entry.rb:112-138`) | Entry: `language`, `encoding`, `subject`; `narrative` | `activities` nil or non-empty; `expiry_time`, `wf_definition`; CareEntry `protocol`, `guideline_id` (`entry.rb:69-78`); `path_attribute :activities, :protocol` |
| `Entry::Activity` (`entry.rb:140-171`) | `description`, `action_archetype_id` (non-empty String) | `timing` optional since RM 1.1.0; `path_attribute :description` |
| `Entry::Action` (`entry.rb:173-204`) | Entry attrs; `time`, `description`, `ism_transition` (with `current_state` validated against the openEHR terminology, `:236-275`) | out of scope here, see section 5 |

`OpenEHR::RM::Composition::Composition` has `path_attribute :content, :context`,
so objects built with the attributes above are navigable by the AQL engine's
path evaluator without engine changes.

## 2. Design -- phase A, no schema change

1. `TYPE_CLASSES` gains `SECTION`, `INSTRUCTION`, `ACTIVITY`.
2. `build_node` gains, per type (each in its own small private helper, because
   `build_node` already sits at rubocop's AbcSize/complexity limits -- PR #50 had to
   extract `node_class` for a one-line change):
   - **Section**: `items` = children built in position order; `nil` when there
     are none (the constructor rejects `[]`).
   - **Instruction**: the same entry defaults as the other entries
     (`language` / `encoding` / `subject`; extend the `is_a?` list);
     `narrative` = the `narrative` data-value row as DvText, **defaulting to the
     node's name** when the row is absent (an injected default, documented like
     `language`); `activities` = children with `rm_attribute_name == 'activities'`,
     `nil` when none; `expiry_time` when its row exists.
   - **Activity**: `description` = the `description` child (ITEM_TREE) -- no
     default: a missing description is an RM-conformance failure and surfaces
     through #44's warning; `timing` = the `timing` row as
     `OpenEHR::RM::DataTypes::Encapsulated::DvParsable` when present;
     `action_archetype_id` = the injected default `'/.*/'` (the RM's "any ACTION
     archetype" pattern) because the graph cannot carry it yet (section 5).
   - **`protocol` for every CareEntry** (Observation, Evaluation, Instruction):
     `attrs[:protocol] = build_node(protocol child)` when present. Same
     mechanism, and it is where `jp_referral` keeps 紹介先/紹介元
     (`service_request` `protocol[at0008]`, anlage memory of 2026-09-25) -- without
     it the INSTRUCTION would be readable but its most-queried data not.
3. `UnsupportedRmTypeError` keeps covering ACTION, ITEM_SINGLE, ITEM_TABLE.

Injected defaults are listed in the class comment next to the existing ones.

## 3. Spec plan (t-wada: red before green), resolution shape (b) enhancement

- **Fixture**: a spec-level synthetic canonical hash (invented ids, stated in the
  comment with this section as design authority; no real canonical JSON with
  SECTION/INSTRUCTION exists in this repo -- anlage's is hand-mapped and outside):
  COMPOSITION whose `content` is `[SECTION { items: [EVALUATION { data: ITEM_TREE {
  items: [ELEMENT DV_TEXT] } }] }, INSTRUCTION { narrative, protocol: ITEM_TREE {
  items: [ELEMENT DV_TEXT] }, activities: [ACTIVITY { description: ITEM_TREE {
  items: [ELEMENT DV_TEXT] }, timing: DV_PARSABLE }] }]`, committed with
  `CompositionCommitter`.
- `rm_object_builder_spec.rb`: **red** today = `UnsupportedRmTypeError`; green =
  `Section` with one `Evaluation` item; `Instruction` with the stored narrative,
  one `Activity` whose `description.items.first.value` is the DvText,
  `action_archetype_id == '/.*/'`, `protocol.items` present; entry defaults on the
  Instruction.
- `executor_spec.rb`: AQL through the new objects --
  `SELECT i/activities[at0001]/description[at0009]/items[at0121]/value/value ...
  CONTAINS INSTRUCTION i[<synthetic id>]` and
  `SELECT i/protocol[at0008]/items[at0010]/value/value`, plus
  `... CONTAINS SECTION s[<id>] CONTAINS EVALUATION ev[<id>]`. Whether the
  engine's CONTAINS chain accepts SECTION/ACTIVITY is **unknown until measured**;
  if it does not, that becomes an openehr-ruby item and the spec pins the `i/...`
  path form only.
- `dataset_adapter_spec.rb` / `executor_spec.rb` (#44): switch the "to_rm fails"
  fixture from SECTION to ITEM_TABLE, which stays unsupported.
- Regression pins: `bmi_calculation` / `problem_list` specs unchanged; full suite
  green; `CanonicalSerializer` round-trip of the new fixture is checked and, if it
  does not survive (`narrative` / `timing` rows), recorded as its own issue rather
  than fixed here.

## 4. Size and schedule

Estimate: +3 map entries; ~50 lines of new helpers plus splitting `build_node`'s
existing per-type `if` blocks into helpers (~80 lines moved, behaviour-neutral,
needed to stay inside the rubocop limits); ~130 lines of specs across three files;
no migration, no generator template change, no dependency change. **Small** by the
ruling's criterion (same builder, one file of runtime code, existing test
infrastructure). Recommendation: **implement before the freeze**, in one PR,
`Fixes #45`, after this plan is approved.

## 5. Out of scope (phase B, December unless pulled forward)

- **Persisting `action_archetype_id`**, `narrative`, `timing` as columns instead
  of injected defaults / data-value rows: needs a migration in
  `lib/generators/**/templates/` (shipped product, host apps migrate) -- its own
  issue and plan.
- **ACTION**: `ism_transition` is persisted today as a generic CLUSTER node
  (`infer_type` falls through), and rebuilding it needs codes valid against the
  terminology; separate design.
- **ITEM_SINGLE / ITEM_TABLE**: no consumer yet.

## 6. Semver

New read-side capability, observable through AQL and `to_rm`: **minor**. If it
lands with #38 (PR #43) and #44 (PR #50), the next release is **0.8.0**, not 0.7.1
-- to be decided at the inventory.

## 7. Stop point

Explore + plan only. Implementation starts on approval.

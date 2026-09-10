# Fix: multi-leaf non-Observation entries constrain a nonexistent `component`

- Status: **ruled 2026-08-27 — option (d), proper mapping, adopted. §§2-6 below are superseded; §8 is the normative spec, as corrected by §9 (the ruling's four corrections, applied 2026-09-10).**
- Target: `openehr-rails` (this repo). No cross-repo work.
- Issue: [#33](https://github.com/skoba/openehr-rails/issues/33)
- Log: `docs/reports/fsh-generator-log.md` (continuing R1-R5)

## 1. Bug summary (from the issue, re-confirmed directly)

`TypeMap::ENTRY_RESOURCES` (`type_map.rb:12-18`) maps openEHR ENTRY types to five
different FHIR R5 resources: `OBSERVATION`→`Observation`, `EVALUATION`→`Condition`,
`INSTRUCTION`→`ServiceRequest`, `ACTION`→`Procedure`, `ADMIN_ENTRY`→`Encounter`.
Only `Observation` has a `component` element in FHIR R5 — confirmed against the
[FHIR R5 Observation resource definition](http://hl7.org/fhir/R5/observation.html);
`Condition`/`ServiceRequest`/`Procedure`/`Encounter` have no equivalent repeatable
slot for arbitrary additional codings/values. `ProfileGenerator#differential_elements`
(`profile_generator.rb:52-60`) and `FshGenerator#build_profile`
(`fsh_generator.rb:26-42`) both choose between a single-leaf `value[x]` path and a
multi-leaf `component` path purely on `entry[:fields].size`, with no check for
whether `resource_type` actually supports `component`. Confirmed via `sushi`:
`problem_list.opt`'s 5-leaf `EVALUATION`→`Condition` entry produces 29
`"No element found at path component..."` errors (matches the issue's own
citation).

This is **not EVALUATION-specific** — it affects any multi-leaf entry mapped to any
of the four non-`Observation` resources. No existing fixture currently has a
multi-leaf `INSTRUCTION`/`ACTION`/`ADMIN_ENTRY` entry, so those paths are untested
today, but the same defect applies to them by construction.

### Related latent dead code, found during this investigation

`TypeMap.value_element(resource_type)` (`type_map.rb:53-58`):
```ruby
def value_element(resource_type)
  resource_type == 'Observation' ? 'value[x]' : 'value[x]'
end
```
Its own comment says "Single-leaf Observations use `value[x]`; everything else hangs
off a component" — but the ternary returns the identical string on both branches, so
it implements none of that. Confirmed via `grep`: **called nowhere in `lib/`** (the
only other hits are unrelated local-variable names in `profile_generator_spec.rb`).
This is exactly the resource-type branch this issue needs, stubbed and never wired
up. Recommend removing it as part of this fix rather than leaving dead, misleading
code that describes behavior it doesn't implement — see §3.

## 2. Options considered

**(a) FHIR Extension-based encoding for non-Observation multi-leaf entries.**
Define a custom complex extension (its own `StructureDefinition`) to carry
additional leaf values on `Condition`/`ServiceRequest`/`Procedure`/`Encounter`,
sliced under `resource_type.extension`. This is the FHIR-canonical way to add
structured data beyond a base resource's element set, and is the only option that
actually *represents* the extra leaves rather than dropping or refusing them.
**Rejected for this issue**: it requires designing and shipping a second
`StructureDefinition` (the extension itself) with its own cardinality/binding/typing
decisions that no prior art in this repo or `anlage`'s design docs addresses (checked
directly: `anlage/docs/design/fsh-plan.md` only says "multi-leaf `component`
slicing" as v1 scope, never anticipates the non-Observation case). Getting an
extension's shape right is a real FHIR-modeling decision with downstream
consequences for anyone consuming these profiles — not something to decide
unilaterally inside a bug-fix issue. Worth a future issue of its own if a real
`EVALUATION`/`INSTRUCTION`/`ACTION`/`ADMIN_ENTRY` multi-leaf template is actually
needed by a consumer (none is, today — see §5).

**(b) Split into multiple linked FHIR resources** (e.g. a primary `Condition` plus
separate `Observation` resources per extra leaf, linked via `Observation.focus`).
**Rejected**: changes the "one profile per ENTRY" architecture
(`profile_generator.rb:8-11`'s own doc comment) into "one-to-many," a much larger
structural change than this issue's scope, and duplicates concerns `#33`'s own
"needs its own explore/plan" framing already flags as too large for this pass.

**(c) Restrict multi-leaf profile generation to `Observation`-mapped entries; raise
a clear, documented error for multi-leaf entries mapped elsewhere.** No data is
silently dropped (an error beats silent corruption) and no unvetted FHIR-modeling
decision is made. The limitation is explicit and testable end-to-end today.
**Recommended** — see §3.

## 3. Recommended fix: (c), restrict + explicit error

- `TypeMap` gains a way to answer "does this resource type support `component`?" —
  replace the dead `value_element` method (§1) with what it should have been:
  ```ruby
  COMPONENT_CAPABLE_RESOURCES = %w[Observation].freeze

  def component_capable?(resource_type)
    COMPONENT_CAPABLE_RESOURCES.include?(resource_type)
  end
  ```
  (A one-element array reads oddly today, but names the actual FHIR fact this repo
  has verified — `Observation` is the only R5 resource among the five in
  `ENTRY_RESOURCES` with a `component` element — and gives future resource-type
  additions one place to declare the same fact, rather than re-deriving it.)
- `ProfileGenerator#differential_elements` (`profile_generator.rb:52-60`): when
  `entry[:fields].size > 1` **and** `!TypeMap.component_capable?(resource_type)`,
  raise a new `OpenehrRails::Fhir::UnsupportedProfileError` (or similar; exact class
  name/placement to be finalized in implementation, not a design-doc-blocking
  detail) with a message naming the entry's archetype id, resource type, and leaf
  count — not a silent skip, not a partial/wrong profile.
- `FshGenerator#build_profile` (`fsh_generator.rb:26-42`): same branch, same error
  class — one shared decision point, not two independently-drifting ones. Consider
  whether the check belongs in a shared location both classes call (e.g. a small
  module method) rather than duplicated inline logic, to avoid the exact kind of
  two-copies drift `#33` itself was born from (`ProfileGenerator` and
  `FshGenerator` independently duplicating the same `size == 1` branch that neither
  originally checked `resource_type` for).
- **Where the error surfaces to a caller**: `ProfileGenerator#profiles` and
  `FshGenerator#to_fsh_files` currently map over `@entries` unconditionally
  (`profile_generator.rb:23-24`, `fsh_generator.rb:17-22`) — a raised error on one
  entry would currently abort the whole batch, silently dropping profiles for
  *other*, unaffected entries in the same template. Decide during implementation
  whether that's acceptable (single-entry templates are today's only real fixtures)
  or whether `profiles`/`to_fsh_files` should skip-and-report per-entry instead of
  raising through the whole batch — flagging this as a design question for
  approval, not deciding it here, since it changes both public methods' contracts
  either way.

## 4. Spec plan (t-wada: red before green)

- New spec (both `ProfileGenerator` and `FshGenerator`, or a shared example group if
  the check ends up in one shared place per §3): parsing `problem_list.opt`
  (5-leaf `EVALUATION`→`Condition`) and calling `.profiles`/`.to_fsh_files` raises
  the new error, with a message that names the archetype id. **Red** today: no
  error is raised; instead a differential/FSH referencing a nonexistent `component`
  path is silently produced. **Enhancement** resolution kind (new documented
  behavior, not a pre-existing property being pinned).
- Regression pin: `bmi_calculation.opt`'s multi-leaf `Observation`-mapped entry
  (`body_mass_index.v2`, 2 leaves) is unaffected — existing
  `profile_generator_spec.rb`/`fsh_generator_spec.rb` coverage of this fixture
  already exercises it; confirm those specs still pass unchanged (they should, this
  fix only adds a new branch for the non-capable-resource case).
- FSH-side confirmation per the issue's own acceptance criteria: after the fix,
  regenerate FSH for `bmi_calculation.opt` and pipe through `sushi` again — expect
  the same 0 Errors/0 Warnings as R2/R3 already established, unchanged.
  `problem_list.opt` no longer produces any FSH to compile (it raises instead), so
  there's nothing left to feed `sushi` for that fixture — satisfies the acceptance
  criterion's spirit (no invalid FSH exists for a case that can't be represented
  correctly yet) without a false claim of validity.

## 5. Compatibility, scope, and semver

- **No existing fixture regresses**: no repo fixture has a multi-leaf
  `INSTRUCTION`/`ACTION`/`ADMIN_ENTRY` entry today, and `problem_list.opt`'s
  `EVALUATION` entry going from "silently wrong" to "clear error" is a bug fix, not
  a behavior anyone could have been relying on (the prior output was invalid FHIR).
- **Host-app impact**: any host app that scaffolded `--fhir` output from a
  multi-leaf `EVALUATION`/`INSTRUCTION`/`ACTION`/`ADMIN_ENTRY` template today has a
  silently-broken generated profile already (confirmed for `EVALUATION` via
  `sushi`; the other three are the same code path). This fix surfaces that as a
  loud error on regeneration rather than continuing to ship invalid output.
  `CHANGELOG.md` should say this plainly.
- **Semver**: raising a new, previously-unraised exception for input that already
  produced semantically-invalid output is a bug fix — **patch**, not minor (no new
  public API surface is added for callers to use; `UnsupportedProfileError`, if
  it becomes part of the public interface at all, is something callers only see
  when hitting the previously-broken case, not a new capability to opt into).
- **`docs/reports/fsh-generator-log.md`** continues as this fix's progress log
  (already tracking `#32`/`#33` as one continuing thread).

## 6. Open questions for approval

1. Confirm option (c) (restrict + explicit error) over (a)/(b) — recommended, but
   this is the actual FHIR-modeling judgment call this design doc exists to get
   signed off on.
2. Per-entry error handling in `profiles`/`to_fsh_files` (§3's last bullet): raise
   through the whole batch, or skip-and-report per entry? No existing fixture has
   more than one entry per template that would surface this distinction today, so
   either choice is currently unobservable in this repo's own fixtures — pick the
   simpler one (raise-through) unless there's a reason to prefer graceful
   degradation now.
3. Exact error class name/namespace (`OpenehrRails::Fhir::UnsupportedProfileError`
   suggested, not fixed).

## 7. Stop point

Explore + design only, per this repo's ticket-driven workflow. Do not implement
until this document is approved. Next steps after approval: implement (Codex per
this repo's division of labor, or directly if the change is judged small enough to
skip that split — decide at approval time), Claude Code review, full
`bundle exec rspec` + full-repo `rubocop` + `sushi` re-verification for
`bmi_calculation.opt`, commit(s), `docs/reports/fsh-generator-log.md` entry.


---

# 8. RULING (2026-08-27): option (d), proper mapping to `Condition`

The recommendation in §3 — option (c), restrict multi-leaf non-`Observation`
entries and raise — **was not adopted**. The ruling directs a *proper mapping*:
`problem_diagnosis`'s leaves land on the real `Condition` elements that mean the
same thing. §§2-6 are kept for the record but are superseded by this section.

**This table is the single specification for both outputs.** `ProfileGenerator`
(the JSON facade) and `FshGenerator` both generate from it; neither may carry a
mapping decision the other doesn't.

## 8.1 Mapping table — `openEHR-EHR-EVALUATION.problem_diagnosis.v1` → `Condition` (FHIR R5)

Measured, not assumed: leaves are `FieldExtractor#entries` output for
`spec/templates/problem_list.opt`; every target element was compiled against
`hl7.fhir.r5.core#5.0.0` with `sushi` 3.16.0 (**0 Errors**) before this table was
written.

| openEHR leaf | Label (fixture, ja) | RM type | → `Condition` element | Rationale |
|---|---|---|---|---|
| *(archetype anchor)* | — | — | `category` — fixed coding `CKM#openEHR-EHR-EVALUATION.problem_diagnosis.v1` | The anchor cannot stay on `code`: under a proper mapping `code` is claimed by at0002, the diagnosis itself. `category` is R5's 0..* CodeableConcept for "what kind of Condition record is this", with an *example* binding, so a fixed archetype coding is legal there. |
| `at0002` | プロブレム・診断名 | `DV_CODED_TEXT`, value set `http://id.who.int/icd/release/11/mms` | `code` 0..1, `only CodeableConcept`, `from <ICD-11 MMS> (required)` | `Condition.code` is "identification of the condition, problem or diagnosis" — the direct counterpart. Its base binding is *example*, so a profile may tighten it to *required*. |
| `at0077` | 発症日時 | `DV_DATE_TIME` | `onsetDateTime` 0..1, `only dateTime` | `onset[x]` is the date/time the condition began; the `dateTime` choice matches `DV_DATE_TIME` exactly. (`sushi` normalises the path to `Condition.onset[x]` with `type: [dateTime]` — that is the shape the JSON facade emits.) |
| `at0003` | 臨床的に認識された日時 | `DV_DATE_TIME` | `recordedDate` 0..1, `only dateTime` | Nearest R5 element. **Approximation, recorded as such**: `recordedDate` is "when this Condition record was created in the system", which is not a synonym for "clinically recognised". No closer element exists in R5; the gap is written down here rather than implied by the mapping. |
| `at0030` | 治癒日時 | `DV_DATE_TIME` | `abatementDateTime` 0..1, `only dateTime` | `abatement[x]` is "the date the condition resolved or went into remission" — the direct counterpart. |
| `at0073` | 診断確度 (`at0074` 疑い / `at0075` 推定 / `at0076` 確定) | `DV_CODED_TEXT`, `terminology_id = "local"` | `verificationStatus` 0..1, `only CodeableConcept`, **no value-set binding emitted** | `verificationStatus` (unconfirmed \| provisional \| differential \| confirmed \| refuted \| entered-in-error) is the semantic counterpart of 診断確度. See 8.2 for why the local codes are deliberately *not* bound. |

**Nothing in this archetype is unmappable** — all five leaves land. What is
deliberately *not* emitted is in 8.2.

## 8.2 Deliberate omissions

- **`at0073`'s local code list (`at0074`/`at0075`/`at0076`) is not bound.**
  `Condition.verificationStatus` has a **required** binding to
  `http://hl7.org/fhir/ValueSet/condition-ver-status`; binding an archetype's
  local at-codes there would be invalid. Translating 疑い/推定/確定 into
  `provisional`/`confirmed`/etc. is a `ConceptMap` concern, outside what a
  `StructureDefinition` can express. The profile therefore constrains the
  element's cardinality and type only. This means the current
  `apply_value_constraints` behaviour — emitting
  `binding: { strength: 'required' }` for any `DV_CODED_TEXT` carrying a local
  `code_list` — must **not** apply to a mapped leaf.
- **Multi-leaf non-`Observation` entries with no mapping table entry keep their
  current behaviour.** The ruling scopes this fix to `problem_diagnosis`; the
  `INSTRUCTION`→`ServiceRequest` case (`request-referral`, arriving with
  referral v2) is reserved as its own Issue rather than generalised here.

## 8.3 Where the table lives

In `TypeMap`, next to `ENTRY_RESOURCES`, keyed by archetype id — the existing
RM-type→FHIR-resource mechanism, not a new conditional scattered across the two
generators. Both generators ask `TypeMap` the same question. The dead
`TypeMap.value_element` (§1) is removed as part of this: it was a stub for
exactly this resource-type branch and never implemented it.

## 8.4 TDD

- **Red**: `problem_list.opt`'s generated FSH under `sushi` 3.16.0 — measured
  **29 Errors** today (all `No element found at path component…`). Pinned as the
  starting measurement.
- **Green**: the same fixture compiles with **0 Errors**. The exact rule set the
  implementation must emit was pre-verified against
  `hl7.fhir.r5.core#5.0.0` before implementation began.
- **JSON facade**: `profile_generator_spec.rb` gains expectations for the mapped
  `Condition` elements, and asserts no `Condition.component` element is produced
  — the original complaint in #33.
- **Regression pin**: `bmi_calculation.opt` (multi-leaf `Observation`) is
  untouched by the new branch and must stay green, `component` slicing intact.

## 8.5 Semver

**Minor.** The JSON facade's output shape changes for `EVALUATION` entries
(`Condition.component` slices disappear, real `Condition` elements appear), which
is observable to any host app consuming `app/fhir/profiles/*.json`. Ships with
`#34`'s `release:check` change; version finalised at release inventory, 0.7.0
expected.

# 9. RULING FOLLOW-UP (2026-09-10): the four corrections to §8, applied

The 2026-08-27 ruling approved §8 **with four corrections**: (1) the archetype
anchor is a *slice* of `category`, (2) `at0003`'s approximation is stated on the
element as a `^comment`, (3) unmapped multi-leaf non-`Observation` entries are
*skipped and reported* per entry, (4) through a named exception class. The
implementation commit `01f31f3` (2026-08-27 12:38 JST) landed 21 minutes after §8
itself (`07767cc`, 12:17 JST) and carries none of them; this repository held no
record of the four points until this section. Applied under the reopened #33.
Everything below was measured against `hl7.fhir.r5.core#5.0.0` with `sushi`
3.16.0 before the code was written, as §8 was.

## 9.1 Correction 1 — the anchor is a slice of `category`

- **Before**: `* category.coding.system = "…"` / `* category.coding.code = #…`
  (JSON: one `Condition.category` element with `patternCodeableConcept`).
- **Why that was wrong**: `Condition.category` is `0..*`. Fixing the coding on the
  element constrains *every* repetition, so a conforming instance could not also
  carry e.g. `problem-list-item` beside the archetype coding.
- **After**: pattern slicing on `$this`, `rules = #open`, `contains ckm 1..1`,
  `category[ckm] = http://openehr.org/ckm/archetypes#<archetype id>` (FSH
  assignment to a `CodeableConcept` is a `patternCodeableConcept`, the same shape
  the JSON facade emits). JSON: two `Condition.category` elements — the slicing
  root (`discriminator: [{type: pattern, path: $this}]`, `rules: open`) and the
  `ckm` slice (`min 1`, `max "1"`, `patternCodeableConcept`). The slice name
  reuses the name the FSH output already gives the CKM coding slice on
  `code.coding`; it is `TypeMap::ANCHOR_SLICE` so both generators share it.
- **Measured**: the candidate rule set compiled to **0 Errors** before
  implementation; the generator's own output afterwards byte-matches the golden
  and compiles to **0 Errors** together with `bmi_calculation.opt`.

## 9.2 Correction 2 — `at0003` carries a `^comment`

§8.1 records `at0003` → `recordedDate` as an approximation in this document only;
the profile now says so itself. `ENTRY_ELEMENT_MAPS` gains a `:comment` key on
the leaf, emitted as `* recordedDate ^comment = "…"` (FSH) and
`ElementDefinition.comment` (JSON) — table-driven, so the two outputs cannot
differ on the wording. Text: *Approximation: openEHR at0003 (Date/time clinically
recognised) has no exact counterpart in FHIR R5 Condition; recordedDate is when
this Condition record was created in the system. See
docs/design/multi-leaf-non-observation-plan.md section 8.1.*

## 9.3 Corrections 3 and 4 — skip-and-report, `UnsupportedProfileError`

These answer §6's open questions 2 and 3.

- **Condition**: an entry with **more than one leaf**, whose base resource is
  **not `Observation`**, and which has **no row** in `ENTRY_ELEMENT_MAPS`. Before
  this section such an entry silently took the `component` path — the original
  #33 defect, still live for `ServiceRequest`/`Procedure`/`Encounter` (the
  `[Unreleased]` CHANGELOG said as much).
- **One decision point** (§3): `TypeMap.assert_supported!(entry)` raises
  `OpenehrRails::Fhir::UnsupportedProfileError` (`archetype_id`, `resource_type`,
  `leaf_count`, and a message naming all three plus #33/#35). Both generators
  call it; neither carries its own conditional.
- **Skip-and-report per entry, not raise-through** (Q2): `ProfileGenerator` and
  `FshGenerator` partition entries at construction, generate for the supported
  ones, and expose the errors in template order through `#skipped`. The batch
  never aborts on one bad entry. The Rails generators (`openehr:fhir_profile`,
  `openehr:scaffold --fhir`) print each skip as `say_status :skip, …, :yellow` —
  the report reaches the person running the generator, and a library caller that
  wants a hard failure re-raises from `#skipped`.
- **Class** (Q3): `OpenehrRails::Fhir::UnsupportedProfileError < StandardError`,
  in `lib/openehr_rails/fhir/unsupported_profile_error.rb`, required before
  `type_map`.
- **Not covered, deliberately**: single-leaf entries. The ruling's wording is
  多葉 (multi-leaf); the single-leaf non-`Observation` path has its own defect,
  recorded in 9.5 rather than folded in here.

## 9.4 TDD (resolution shape (b) enhancement for all four)

- **Red**: specs written first in `fsh_generator_spec.rb` and
  `profile_generator_spec.rb` (slice, `^comment`/`comment`, skip-and-report,
  `#skipped` empty for an all-`Observation` template) plus the regenerated
  golden: **36 examples, 12 failures** on the pre-correction code.
- **Green**: `spec/openehr_rails/fhir/`: **48 examples, 0 failures**; full suite
  **304 examples, 0 failures** (295 before).
- **Synthetic entry, spec-level, not a fixture file**: no real multi-leaf
  `INSTRUCTION` OPT exists in this repo (#35 is blocked on exactly that), so the
  skip-and-report specs stub `FieldExtractor` to return `problem_list.opt`'s real
  entry plus one invented `INSTRUCTION` entry
  (`openEHR-EHR-INSTRUCTION.synthetic_unmapped_test.v1`, two of the real leaves
  relabelled). The id is self-evidently invented; the spec comment says so and
  points here.
- **Golden**: regenerated from the corrected generator, diffed against the
  pre-verified candidate (identical), then compiled again: **0 Errors**.

## 9.5 Residual found while measuring 9.1 — not fixed here

A single-leaf non-`Observation` entry still takes the legacy path and emits
`* value[x] 0..1` (FSH) / `<Resource>.value[x]` (JSON). `Condition` has no
`value[x]` either: a hand-written probe (`Parent: Condition`, `* value[x] 0..1`)
compiled under the same `sushi` run to **1 Error**, `No element found at path
value[x] for CardRule`. No fixture in this repository reaches that path
(`problem_list.opt` is 5-leaf; every single-leaf fixture entry is
`OBSERVATION`), so nothing observable regressed. Outside the ruling's scope
(多葉); filed as its own bug Issue rather than widened into #33 — the natural fix
is to extend `assert_supported!` to it, but that is a second contract change and
gets its own red spec.

## 9.6 Semver

Still **minor**, on top of §8.5: `#skipped` and `UnsupportedProfileError` are
new public API; the `category` anchor and the `comment` change the JSON facade's
shape again for `EVALUATION` entries. `CHANGELOG.md` `[Unreleased]` updated in
the same change.

## 9.7 #38 (2026-09-10 ruling): the decision point widened to any leaf count

The ruling on 9.5 allowed #38 to ride in 0.7.0 if it stayed on the same
decision point, small, and green. It does: `TypeMap.assert_supported!` drops
its `fields.size <= 1` early return, so *any* entry whose base resource is not
`Observation` and which has no `ENTRY_ELEMENT_MAPS` row is skipped and
reported -- a single leaf would have produced `<Resource>.value[x]`, which
`Condition` / `ServiceRequest` / `Procedure` / `Encounter` lack just as they
lack `component` (measured: 1 sushi Error on the 9.5 probe). The error message
now names both missing elements and the leaf count in the singular where it is
one. Resolution shape (a) bug.

- **Fixture check before widening**: every OPT under `spec/templates/`,
  `spec/generators/templates/` and `demo_assets/templates/` was listed with
  `FieldExtractor#entries` -- all single-leaf entries are `OBSERVATION`
  (`height.v2`, `body_weight.v2`, `heart_rate-pulse.v1`); the only
  non-`Observation` entry is `problem_diagnosis.v1` (5 leaves, mapped). So no
  fixture's output changes. (`spec/templates/sample_blood_pressure.opt` does not
  parse at all -- `ArgumentError: invalid archetype id form` -- under openehr
  2.4.2 *and* 2.4.3, and no spec references it; pre-existing, noted in
  `docs/backlog.md`, not touched here.)
- **Red**: 4 new examples (two per generator, synthetic single-leaf
  `EVALUATION` entry `openEHR-EHR-EVALUATION.synthetic_single_leaf_test.v1`):
  **40 examples, 4 failures** across the two spec files.
- **Green**: the same files 40/0; `spec/openehr_rails/fhir/` 52/0; full suite
  308/0. Regenerated FSH for `problem_list.opt` + `bmi_calculation.opt`
  byte-identical to before and **0 Errors** under `sushi` 3.16.0 -- the pin.
- **Semver**: rides in 0.7.0; on its own a bug fix (patch) that changes no
  fixture output, only what an unmapped single-leaf non-`Observation` entry
  yields (invalid FHIR before, a `#skipped` entry now).

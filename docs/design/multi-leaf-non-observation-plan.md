# Fix: multi-leaf non-Observation entries constrain a nonexistent `component`

- Status: **ruled 2026-08-27 — option (d), proper mapping, adopted. §§2-6 below are superseded; §8 is the normative spec.**
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

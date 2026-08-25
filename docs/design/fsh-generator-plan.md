# Enhancement: FshGenerator (FSH output alongside ProfileGenerator)

- Status: draft, approved-by-citation (design decisions made upstream in
  `skoba/anlage#17`, not re-litigated here)
- Target: `openehr-rails` (this repo)
- Issue: [#32](https://github.com/skoba/openehr-rails/issues/32)
- Log: `docs/reports/fsh-generator-log.md`
- Design authority: `skoba/anlage`'s `docs/design/fsh-plan.md` (2026-08-26
  ruling, all 4 judgments approved) and `docs/reports/fsh-log.md` R1-R4.
  This doc translates that already-approved plan into this repo's
  file:line reality; it does not re-decide source/scope/output-form.

## 1. Summary

Add `OpenehrRails::Fhir::FshGenerator`, a sibling to
`OpenehrRails::Fhir::ProfileGenerator` that renders FSH (FHIR Shorthand)
text instead of a JSON StructureDefinition Hash, from the exact same
input: `OpenehrRails::Opt::FieldExtractor#entries`. No independent OPT
walk — this is the "share the intermediate representation" design
anlage's plan settled on (rejecting a pathcards-based or
independently-walking alternative as violating the no-double-derivation
constraint).

## 2. Input contract (already shipped, `skoba/openehr-rails#30` / 0.5.0)

`FieldExtractor#entries[].fields[]` now always carries (verified live
in `field_extractor.rb:160-177`, doc comment `field_extractor.rb:1-23`):

- `value_set_uri`: `C_CODE_REFERENCE#reference_set_uri`, else `nil`
- `code_bindings`: `[{system_uri:, code:}]`, else `[]` — not limited to
  `DV_CODED_TEXT` (BMI's LOINC binding sits on a `DV_QUANTITY` element,
  `CHANGELOG.md` [0.5.0] Added note)

No further gem work is a prerequisite for this Issue.

## 3. v1 scope (per the approved anlage plan, §"v1サブセットの範囲確定")

Mirror exactly what `ProfileGenerator` already emits, in FSH syntax,
plus binding writes (now unblocked):

| JSON (`profile_generator.rb`) | FSH form |
|---|---|
| `build_profile` metadata (`:33-50`) | `Profile:`/`Parent:`/`Id:`/`Title:` header lines |
| `code_element` (`:62-69`) | `* code.coding.system = ...` / `* code.coding.code = ...` (or a `patternCodeableConcept`-equivalent assignment — pick whichever Sushi compiles identically to the JSON shape; verify by comparing compiled output, not by assumption) |
| `value_elements` (`:71-80`) | `* value[x] <min>..<max>` + `* value[x] only <Type>` |
| `component_elements`/`component_slice` (`:82-113`) | slicing declaration (`^slicing.discriminator...`) + `* component contains <slice> <card>` + per-slice `code`/`value[x]` assignment (see anlage's `docs/reports/fsh-log.md` R1 for a working Sushi-verified example of this exact shape) |
| `DV_QUANTITY` unit (`apply_value_constraints`, `:117-124`) | `* value[x].unit = "..."` (or equivalent fixed-value rule) |
| `DV_CODED_TEXT` binding (`:125-131`, now includes `valueSet`) | `field[:value_set_uri]` present → `* value[x] from <uri> (required)`. `field[:code_bindings]` present (any rm_type) → fixed `patternCodeableConcept`-equivalent assignment per binding entry |

Explicitly out of scope for v1 (matches the JSON facade's own gaps, not
new ones introduced here): `magnitude_range` (extracted but never
emitted by `ProfileGenerator` either — a separate, pre-existing gap).
`mml_referral`-scale templates are out of v1's verification scope per
the approved plan (size cap); this Issue's fixtures stay to the 3 small
ones listed below.

## 4. Fixtures (no new SNOMED literal budget — reuse what's already here)

- `spec/generators/templates/bmi_calculation.opt` — single-leaf,
  `DV_QUANTITY`, real SNOMED-CT (`60621009`) + LOINC `code_binding` on
  `at0004` (`spec/templates/bmi_calculation_without_uid.opt:1683-1697`
  for the byte-identical sibling with visible XML)
- `spec/templates/problem_list.opt` — `C_CODE_REFERENCE`/ICD-11
  `value_set_binding` on `at0002`, local `code_list` contrast on
  `at0073` (byte-identical copy of anlage's `ProblemList.opt`,
  provenance comment already in the file per `0bbbc47`)

Both are already indexed by existing specs
(`spec/openehr_rails/fhir/profile_generator_spec.rb`,
`spec/openehr_rails/opt/field_extractor_binding_spec.rb`) — reuse the
same `template` `let` pattern.

## 5. TDD (t-wada, per this repo's CLAUDE.md)

1. Red/Green: `FshGenerator` non-binding v1 subset against
   `bmi_calculation.opt` — metadata, single-leaf `value[x]`, unit. Fix
   the exact FSH text with a golden spec (string equality or a small
   set of `include` assertions on stable substrings — match whichever
   style `profile_generator_spec.rb` already uses for the JSON side)
2. Red/Green: `code_binding` write against `bmi_calculation.opt`'s
   `at0004` (SNOMED-CT `60621009` and/or the LOINC binding — pick
   whichever demonstrates the fixed-value FSH form most clearly)
3. Red/Green: `value_set_binding` write against `problem_list.opt`'s
   `at0002` (ICD-11) — fix the `from <uri> (required)` line
4. Red/Green: multi-leaf `component` slicing — `bmi_calculation.opt`'s
   `openEHR-EHR-OBSERVATION.body_mass_index.v2` entry already has 2 leaf
   fields (verified: `bundle exec ruby` with `FieldExtractor#entries`,
   2026-08-26), and `at0004`'s SNOMED/LOINC `code_binding` sits inside
   this same multi-leaf entry — one fixture covers both slicing and
   binding for this case. No new fixture needed (`problem_list.opt` also
   has 5 leaf fields, `lab_result_report_reduced.opt` has 3, for
   reference)
5. Manual verification (not part of this Issue's automated suite,
   done once locally before closing): pipe generated FSH through
   `fsh-sushi` and confirm 0 Errors, matching the shapes anlage already
   verified by hand (`docs/reports/fsh-log.md` R1 in `skoba/anlage`)

## 6. Structural note

`FshGenerator` takes only `FieldExtractor#entries` (or a `template` it
extracts from, same as `ProfileGenerator.new(template)`) — no
`ActiveRecord::Base`/`Rails` dependency. This keeps it relocatable if a
future `openehr-fhirbridge` satellite gem is split out (anlage
`docs/backlog.md` item 5, not a decision made in this Issue).

## 7. Out of scope here

- CI wiring for Sushi verification (anlage-side decision, ruled out for
  v1 — `docs/design/fsh-plan.md`'s 判断3 in `skoba/anlage`)
- The `rake fsh:export` output path (anlage-side, `skoba/anlage`'s own
  Issue #17 scope)
- Any RubyGems release/publish step (human-gated per this repo's
  `docs/backlog.md` "Release automation" / `skoba/openehr-rails#27`)

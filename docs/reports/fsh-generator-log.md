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

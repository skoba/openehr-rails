# Binding extraction log

Terse, chronological record of the FieldExtractor terminology-binding-extraction task
(openehr-rails#30, drafted upstream from `skoba/anlage`'s `fsh-plan.md` arbitration,
2026-08-26). One entry per step; not a design doc, not a status board -- just what
happened, with evidence (issue/commit/PR references). No chat report per step; a single
bundled report goes to the user at completion.

## R1 -- Filing (Step 0)

Filed openehr-rails#30 ("FieldExtractor never extracts external terminology bindings
(value_set_binding / code_binding)"), reconstructed from Anlage's draft
(`anlage/docs/upstream/issues/openehr-rails--field-extractor-missing-terminology-bindings.md`)
into this repo's `bug_report.md` template shape (Summary/Environment/Reproduction/
Expected vs Actual/Root cause/Proposed fix/Acceptance criteria). Labels: `bug`,
`enhancement` (repo has no `field-extractor`/`fhir` labels; none created).

Corrections made to the draft during verification (Explore workflow, 3 parallel agents
across openehr-rails/anlage/openehr-ruby, read-only):

- Environment: `openehr` dependency corrected to this repo's actual lock (gemspec
  `~> 2.3`, `Gemfile.lock` locked at **2.3.0**) -- the draft's "2.4.2" was Anlage's own
  environment value, not this repo's. Recorded that 2.3.0 crashes parsing
  `C_CODE_REFERENCE` OPTs (`skoba/openehr-ruby#30`, fixed in 2.3.1), so the
  value_set_binding half needs a gemspec floor raise before it can even be exercised.
- Root cause: added that `ProfileGenerator#apply_value_constraints`'s DV_CODED_TEXT
  branch (`profile_generator.rb:125-128`) is worse than the draft stated -- when
  `field[:code_list]` is empty (the `C_CODE_REFERENCE` case), it returns before setting
  `element[:binding]` at all, not just omitting `valueSet`. Fixing this is a
  restructure, not a one-line addition.
- Line-range drift: `bmi_calculation_without_uid.opt`'s at0004 term_bindings span
  1683-1702, not 1683-1697 as drafted; the fixture also carries two more term_bindings
  (LOINC 8302-2 at 721-730, LOINC 29463-7 at 1215-1224) not mentioned in the draft.
  There is no `bmi_calculation.opt` in `spec/templates/` (only `spec/generators/
  templates/bmi_calculation.opt`, which the draft's citation didn't distinguish).
- "OPTParser drops term_bindings" precision: scoped explicitly to `OPTParser` --
  `ArchetypeOntology#term_bindings` already exists as a receiving slot upstream
  (`ontology.rb:8`) and `XMLArchetypeParser` already populates it
  (`xml_archetype_parser.rb:189`); only `OPTParser` (the class this repo's `Parser`
  subclasses) never reads them (`skoba/openehr-ruby#31`, OPEN).
- Reference implementation naming: confirmed the class is `Opt::PathcardExtractor`
  (anlage `app/lib/opt/pathcard_extractor.rb:243-289`) -- no `TermBindingExtractor`
  class exists in anlage. Also confirmed anlage's code carries no removal-condition
  comment tied to `#31` (that management form exists only in anlage's design docs);
  the draft's instruction that the rails port *should* add such a comment is kept and
  will be honored in the design doc / implementation.
- Cross-reference: the arbitration record lives in `anlage/docs/design/fsh-plan.md`
  ("裁定反映" section, 2026-08-26), not in `skoba/anlage#17`'s GitHub thread (0 comments
  there) -- citation corrected accordingly.
- Added to Proposed fix / scope (adversarial design review, see design doc): a real
  CKM-authored OPT (anlage's `ProblemList.opt`) has a `value` attribute with two
  alternatives (DV_TEXT first, `C_CODE_REFERENCE`-constrained DV_CODED_TEXT second).
  `FieldExtractor#value_constraint` currently takes `children.first` unconditionally
  (`field_extractor.rb:174-178`), which would leave `value_set_uri` permanently nil on
  exactly the OPT shape motivating this issue. Anlage's `primary_value_alternative`
  (`pathcard_extractor.rb:137-145`) selection logic is ported in as part of this same
  issue (user-arbitrated 2026-08-25, not deferred to a follow-up).

Design produced via two independent Plan-agent passes (primary design + adversarial
alternatives/edge-case review) that converged on parse-time enrichment inside
`OpenehrRails::Opt::Parser#parse`, populating the existing upstream
`ArchetypeOntology#term_bindings` slot in the same canonical shape `XMLArchetypeParser`
already produces, with a nil-guard so the bypass self-deactivates and becomes a
pure deletion once `skoba/openehr-ruby#31` lands upstream. Fixture decision
(user-arbitrated 2026-08-25): copy anlage's real `ProblemList.opt` wholesale into
`spec/templates/problem_list.opt` (kind: real, provenance comment citing anlage's
sha256 and CKM/Archetype-Designer lineage) rather than hand-reducing it.

Full design detail: `docs/design/binding-extraction-plan.md` (to be written in Step 1,
opening with issue #30 per convention).

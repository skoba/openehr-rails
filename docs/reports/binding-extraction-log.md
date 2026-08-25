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

## R2 -- Design doc (Step 1)

Wrote `docs/design/binding-extraction-plan.md` (opens with issue #30, per convention).
Direct verification performed while writing (not just carried forward from R1's
Explore-agent findings):

- Confirmed `OpenEHR::RM::DataTypes::Text::CodePhrase` and
  `OpenEHR::RM::Support::Identification::TerminologyID` are the correct fully-qualified
  constant paths (openehr-ruby `lib/openehr/rm/data_types/text.rb:6-9,60`,
  `lib/openehr/rm/support/identification.rb:4-8,152`).
- Read OPT's actual `term_bindings` XML structure directly
  (`spec/templates/bmi_calculation_without_uid.opt:1683-1702`) and found it is
  **structurally different** from ADL/XML-archetype `term_bindings`
  (`xml_archetype_parser.rb:189,214-230`) — the latter is a flat
  `terminology="..." code="..."` + single qualified-reference text node, split by
  `code_phrase_from_binding`; OPT's is a `term_bindings[@terminology]` wrapping nested
  `items[@code]/value/{terminology_id/value, code_string}` (a serialized CODE_PHRASE,
  already bracketed-qualified, no `::`-splitting needed). This meant the initial design
  sketch's "reuse XMLArchetypeParser's ontology_bindings logic" framing was corrected
  to: match its **target in-memory shape** only, read OPT's own XML structure directly
  (mirroring anlage's `extract_code_bindings`, not `ontology_bindings`).
- Probed a `term_bindings` element's ancestor chain directly (small Python/lxml script
  against the bmi fixture) and confirmed the nearest ancestor carrying `archetype_id`
  is the owning `children[@archetype_id]` (`C_ARCHETYPE_ROOT`) node — so a
  nearest-ancestor-first walk attributes bindings correctly, including for embedded
  archetypes (consistent with #25's per-element archetype_id threading).
- Computed anlage `ProblemList.opt`'s sha256 directly
  (`b821b98beebfba9e758cc0429a91bb98aedb7d50de684424f0eb58d51e4a47c1`) rather than
  transcribing the Explore agent's (truncated) citation, for the fixture's provenance
  comment text.
- Confirmed `ArchetypeOntology#term_bindings=` has no validation/mandatory-arg
  constraint (`ontology.rb:7-24`), so post-construction assignment
  (`terminology.term_bindings = bindings`) is safe.

Design doc records: parse-time enrichment location and exact method sketch, the
corrected XML-structure understanding above, the primary-value-alternative port
(§4, user-arbitrated 2026-08-25 to include in this same issue), the ProfileGenerator
restructure (not a one-line fix), the dependency-floor/lockfile prerequisite, the real
`problem_list.opt` fixture plan with provenance text, a 5-step TDD sequence with
red/green expectations and resolution-kind (enhancement vs bug) per spec, compatibility
notes (CHANGELOG draft, host-app cache regeneration, semver=minor rationale), and a
deferred/out-of-scope register (§9).

Gate: reporting to the user for approval before Step 2 (branch + Codex implementation).

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

## R3 -- Step 2 kickoff: push, CLAUDE.md addendum, fixture, dependency floor

User approved Step 2 with five conditions (0-4, plus a no-tag note). Executed
immediately (condition 0): pushed the two local-only R1/R2 commits to
`origin/master` (`c586a8c`, `5470d29`). Added the one-line CLAUDE.md addendum the
user specified ("gate report artifacts must be pushed"), as its own commit
(`c7a577f`), pushed.

Created branch `feature/field-extractor-terminology-bindings` (1 issue = 1 branch =
1 PR). Copied anlage's `ProblemList.opt` into `spec/templates/problem_list.opt`
(condition 2: provenance header declares Anlage canonical, cites both the file's
sha256 and the anlage commit that introduced it, `7466c80`, verified present as of
anlage HEAD `706e4a7`). Verified the copy byte-identical to the source via `diff`
before committing (`0bbbc47`).

Directly smoke-tested parsing `problem_list.opt` against the then-current openehr
2.3.0 lock: raises `NoMethodError: undefined method 'c_code_reference'` — the exact
#30 crash the design doc predicted. Wrote
`spec/openehr_rails/opt/parser_problem_list_spec.rb` (regression-pin, not
enhancement: pins that the floor raise fixes what it claims to, not new
FieldExtractor/ProfileGenerator behavior) and confirmed it red via `bundle exec
rspec` before touching the gemspec.

**Correction found while executing (not part of the original design)**: `*.lock` is
gitignored in this repo (`.gitignore:30`) -- `Gemfile.lock` and the three
`gemfiles/rails_*.gemfile.lock` files are not tracked in git at all. CI
(`ruby/setup-ruby@v1` with `bundler-cache: true`) resolves a fresh lockfile from the
gemspec constraint on every run. This means the design doc's "all four lockfiles
must move together or a CI leg breaks" framing was wrong -- there is no committed
lockfile to go stale. Corrected `docs/design/binding-extraction-plan.md` §5.4 and §7
step 1 accordingly. The gemspec floor raise (`~> 2.3`, `>= 2.3.1`) is the only
committed change; `bundle update openehr` was still run locally across all four
gemfiles (to unblock local test runs against each), producing no diff to commit.

Raised the gemspec floor, ran `bundle update openehr` locally (resolved to 2.4.2),
confirmed the new spec green, then ran the full existing suite: **265 examples, 0
failures** -- the dependency bump alone changes no existing rails behavior, as
expected.

Design-doc TDD plan's step 1 (§7) is complete. Next: hand off to Codex for steps
2-5 (parser.rb term_bindings enrichment, FieldExtractor key additions +
primary_value_alternative port, ProfileGenerator restructure, remaining specs),
per condition 1.

## R4 -- Codex implementation, independent review, commit (#30 steps 2-4/5)

Launched `codex exec -C /home/skoba/src/openehr-rails --approve-for-me` (first
attempt with `-s workspace-write` combined with `--approve-for-me` errored --
those two flags are mutually exclusive on this codex-cli version; retried with
`--approve-for-me` alone, which succeeded) against a prompt covering design doc
sections 5.1-5.3 and TDD-plan steps 2-4, explicitly scoped away from step 1 (already
done) and from touching fixtures/gemspec/lockfiles.

Codex delivered working-tree-only changes (no commits, as required): `parser.rb`
(`populate_term_bindings!` + 3 helper methods, matching the design doc's method
sketch closely including the exact Japanese 撤去条件 comment),
`field_extractor.rb` (`value_set_uri`/`code_bindings` keys, `primary_value_alternative`
port into `value_constraint`, a `defining_code_of` refactor unifying duplicated
lookup logic), `profile_generator.rb` (the DV_CODED_TEXT branch restructure), three
spec files, and a `CHANGELOG.md` [Unreleased] entry. Self-reported: 275 examples/0
failures, RuboCop clean on touched files, no commits made.

**Independent review performed** (not just trusting the self-report): read every
diff hunk against the design doc section by section (5.1/5.2/5.3 each matched
closely); re-ran the full suite myself (confirmed 275 examples, 0 failures) and
RuboCop on all seven touched/added files myself (found one offense --
`Style/ExpandPathArguments` -- in `parser_problem_list_spec.rb`, a file I had
authored in R3, not a Codex file; fixed directly). Verified `git diff --check`
clean and that no fixture/gemspec/lockfile was touched. Spot-checked the trickier
spec assertion (`profile_generator_spec.rb`'s "keeps a local code-list binding free
of a valueSet" -- walks `elements.drop(code_index + 1).find { |e| e[:type] }` to
locate the matching value element) against `ProfileGenerator#component_slice`'s
actual output shape and confirmed it's unambiguous (code_path/code_constraint have
no `:type` key; the immediately-following value_constraint does).

**Incident, caught and recovered before it caused loss**: while splitting Codex's
delivery into staged commits (isolating the parser.rb change to verify it was
independently green via `git stash push --keep-index -u`), the stash command
printed a pathspec error (`Too many revisions...` / a pathspec-magic parse error)
for `field_extractor_binding_spec.rb` specifically, and that untracked file then
appeared to be missing from both the working tree and `git stash show -p`'s
summary. Before assuming data loss, verified: the file's exact content was still
present in this session's own context (read via `cat` minutes earlier for the
diff review above), recreated it from that content, then confirmed via
`git ls-tree stash@{0}^3` that the stash's untracked-files commit had, in fact,
captured the file all along (the error was cosmetic/non-fatal) -- diffed my
recreated file against the stash's copy: byte-identical. No data was actually
lost; dropped the redundant stash and re-ran the full suite to confirm the working
tree was intact (275 examples, 0 failures) before proceeding. Abandoned the
per-step stash-verification approach as not worth the risk for marginal benefit;
committed steps 2-4 as one cohesive commit instead (the three files are tightly
coupled -- one feature, reviewed and tested together).

Committed as two commits: `2448588` (the RuboCop fix, mine) and `6efc161` (Codex's
implementation, `Implemented-by: Codex` trailer, full description of every
component). Pushed both.

Gate: proceeding to PR (`Fixes #30`) and the pre-merge gate report per condition 3
(pushed SHAs, full suite/CI, both binding types' actual extraction, and a
ProfileGenerator JSON diff showing `valueSet` appear).

## R5 -- PR, merge, and the three pre-merge conditions

Opened PR #31 (`Fixes #30`). CI: 11/11 checks passed (spec matrix x9, demo smoke,
template smoke), GitHub Actions run 32823731709. Ran a scratch demonstration
(`/tmp/.../gate_evidence_spec.rb`, not committed) proving both binding types extract
from real fixtures and that `ProfileGenerator`'s JSON facade now emits `valueSet`;
included in the pre-merge gate report to the user alongside the pushed-SHA list and
suite/CI results.

User approved merge with three small pre-merge conditions, all addressed before
merging:

1. **Fixture provenance check** -- `problem_list.opt`'s header already had the
   canonical declaration (anlage SHA `b821b98b...`, introducing commit `7466c80`,
   verified-as-of anlage HEAD `706e4a7`) from R3. Found a real disambiguation need
   though: this repo already has `demo_assets/templates/problem_list.opt` (English,
   2024-02-16, `repositoryId=openehr-lesson`, zero `term_bindings`/`referenceSetUri`)
   -- a same-named but unrelated fixture used by the demo app. Added a one-line
   disambiguation to the header (`924c37a`); verified the XML body still
   byte-identical to anlage's source both before and after.
2. **SNOMED literal-budget count** -- counted directly: 2 occurrences in spec
   expectation code (`field_extractor_binding_spec.rb:40`,
   `parser_term_bindings_spec.rb:28`), both the same code value `60621009`, both
   citing the same source fixture line. Recorded a new `docs/backlog.md` "Fixture
   conventions" section adopting Anlage's C2-firewall-style budget policy (SNOMED CT
   minimal-and-cited; LOINC exempt, permissive license) with this count as the
   baseline (`8edb25a`).
3. **Incident-recovery principle** -- added to `CLAUDE.md`'s Verification section:
   search git's own storage (stash/reflog/fsck) before reconstructing a seemingly-lost
   file from memory, and independently diff-verify any reconstruction used (`8edb25a`,
   same commit as item 2).

Both docs commits landed on the feature branch (not master directly, unlike the
earlier gate-reporting-push CLAUDE.md addition in R3) -- a minor inconsistency in
where repo-wide convention changes land, accepted rather than corrected via further
git surgery, since they reach master via the merge regardless.

**Merged PR #31** via `gh pr merge 31 --merge --delete-branch=false` (regular merge
commit, no squash/rebase, per condition). Merge commit `eb08b23`. Fast-forwarded
local `master` to it, re-ran the full suite directly on `master`: **275 examples, 0
failures**. Confirmed issue **#30 auto-closed** (`state: CLOSED`,
`stateReason: COMPLETED`, `closedAt` matching the merge timestamp exactly).

Next: condition 4 (comment on `skoba/openehr-ruby#31` with three findings, English,
addendum to the existing WP2-style comment) and condition 5 (release inventory +
0.5.0 proposal, noting Anlage's FSH downstream dependency on this release actually
shipping).

## R6 -- Upstream knowledge comment on openehr-ruby#31 (cross-repo, target: skoba/openehr-ruby)

Posted an addendum comment to `skoba/openehr-ruby#31` (English, matching the
existing WP2-comment's numbered-section format, explicitly framed as a follow-up to
that comment rather than a duplicate):
https://github.com/skoba/openehr-ruby/issues/31#issuecomment-5407936806

Three findings recorded there: (1) OPT's `term_bindings` XML shape differs
structurally from `XMLArchetypeParser`'s (flat attribute+text vs. nested
items/value) -- only the target in-memory shape should be reused by a future
`OPTParser` fix, not the ADL-side XML-reading logic; (2) a second, independent
reference implementation now exists (`openehr-rails`'s `populate_term_bindings!`,
populating `ArchetypeOntology#term_bindings` directly with a nil-guard removal
condition, vs. anlage's side-channel `Hash`) -- two independent implementations
converging on the same target shape is a signal for what the upstream shape should
be; (3) a single at-code can carry simultaneous bindings to more than one
terminology (BMI's `at0004`: both SNOMED-CT and LOINC at once) -- not previously
recorded on this issue, and a constraint the eventual fix's data shape must support.
Explicitly did not commit anlage or openehr-rails to auto-removing their bypasses
once this issue ships (separate future work on each side).

## R7 -- Release inventory (v0.4.1..master) and 0.5.0 proposal

Classified every non-merge commit since `v0.4.1` (33 commits; per-commit file lists
pulled directly via `git log --name-only`, not asserted from memory) against
CLAUDE.md's release convention:

- **Neutral (30 commits)**: everything touching only `CLAUDE.md`, `docs/**`,
  `.github/ISSUE_TEMPLATE/**`, `.github/workflows/**`, or a `spec/**` fixture/spec
  file. Includes the institutionalization work (#29), the release-path CI fix (#28),
  and #30's own docs/fixture/spec-only commits (`0bbbc47`, `924c37a`, `2448588`,
  design doc and report log commits). Fixture-comment-only fixes (`6d8f284`,
  `03d3808`) classified neutral too, consistent with how `v0.4.1`'s own CHANGELOG
  entry treated the same kind of change (not mentioned there either) -- test assets
  are packaged via `gem.files = \`git ls-files\`` but are not shipped runtime code,
  not executed by any consuming application, and don't change public API or
  install-time dependencies.
- **`c571bf5`** (openehr dependency floor `~> 2.3` -> `~> 2.3, >= 2.3.1`): touches
  the gemspec's runtime dependency declaration -- one of the three surfaces the
  convention names explicitly. Classified **minor**, following this repo's own
  `v0.4.1` errata precedent (a `required_ruby_version` floor raise was called
  minor-level there; an equivalent gem-dependency floor raise here gets the same
  treatment).
- **`6efc161`** (the FieldExtractor/Parser/ProfileGenerator feature commit): touches
  `lib/` directly, adds two new always-present field-hash keys (new public API
  surface) and fixes the `ProfileGenerator` `valueSet` omission bug. Classified
  **minor** (new backward-compatible functionality dominates; the bug fix alone
  would only be patch).

No commit removes or breaks existing public API -- the `ProfileGenerator` change is
purely additive (adds a binding where none existed; the existing local-`code_list`
case is regression-pinned unchanged) and the multi-alternative `rm_type` change only
affects OPT shapes no existing fixture has. **Overall: minor**, i.e. `v0.4.1 ->
v0.5.0`. This is a content-driven conclusion (not merely riding the pre-existing
`docs/backlog.md` "next release must be >= 0.5.0" floor, though it also satisfies
that floor with no conflict to arbitrate). `CHANGELOG.md`'s current `[Unreleased]`
content (Added/Fixed/Changed, already written at merge time per this repo's
record-batching convention) matches this classification with no further edits
needed beyond finalizing the version header.

**Downstream dependency flagged**: `anlage`'s FSH export (`skoba/anlage#17`,
`docs/design/fsh-plan.md` "コミット分割" 後段) has its binding-mapping step blocked
specifically on `openehr-rails` actually **shipping** a release containing this
work -- anlage consumes `openehr-rails` as a gem dependency and can only pick up
`field[:value_set_uri]`/`field[:code_bindings]` via a `bundle update` once `0.5.0`
(or later) is published, not merely merged to this repo's `master`. Merging PR #31
(R5) satisfies anlage's *design* prerequisite; it does not yet satisfy anlage's
*consumption* prerequisite -- that needs an actual tagged, gem-pushed release.

**Recommendation: proceed to 0.5.0.** Not executed yet in this pass -- prepared
mechanically (version bump, CHANGELOG header) and the tag itself are held for an
explicit go-ahead, since tag-push is a public, only-partially-reversible action.
Noted for that step: this repo's `release.yml` (fixed in PR #28, per `docs/backlog.md`
"Release automation") only runs CI + `rake build` + artifact-upload on a `v*` tag
push -- it does **not** push to RubyGems automatically (that remains a deliberate,
separate human `gem push`, the established operating model per the same backlog
section). So tagging `v0.5.0` and pushing the tag is lower-risk than it might sound;
publishing to RubyGems is a distinct, later, human-executed step. This would also be
the **first real tag to exercise PR #28's fixed release path end-to-end** -- its own
body deferred that verification to "the next real release (>= 0.5.0)," which this is.

## R8 -- v0.5.0 tagged, release.yml verified green, artifact reproducibility confirmed

User approved tagging. Executed:

1. `lib/openehr_rails/version.rb` bumped `0.4.1` -> `0.5.0`; `CHANGELOG.md`'s
   `[Unreleased]` retitled to `## [0.5.0] - 2026-08-25` (fresh empty `[Unreleased]`
   left above it), matching the exact pattern the `0.4.1` release-bump commit used
   (`2cddb0d`, verified by reading its diff directly rather than guessing the
   convention). Full suite re-run after the bump: 275 examples, 0 failures.
   `bundle exec rake release:check` failed first (dirty tree, expected -- the check
   requires a clean tree), then passed clean after committing (`69db63f`, pushed).
   `git tag -a v0.5.0` (annotated, full CHANGELOG-derived message) and
   `git push origin v0.5.0`.

2. **`release.yml` run verified green end-to-end** -- GitHub Actions run
   [32831263811](https://github.com/skoba/openehr-rails/actions/runs/32831263811),
   triggered by the `v0.5.0` tag push. Overall conclusion: **success** (confirmed via
   the run's own `conclusion` field, not inferred from individual step icons). All 12
   jobs green: the 9 reused `ci.yml` spec-matrix jobs, `demo smoke`, `application
   template smoke test`, and `Build gem artifact` (its `release:check`, `Build gem`,
   and `Upload gem artifact` steps all succeeded). This is the **first tag-push run
   with a fully green overall conclusion** -- `v0.4.1`
   (`32550344344`) and `v0.4.0` (`31660884406`) were both structurally red at the
   now-removed RubyGems-publish step (`docs/backlog.md` "CI status" section); that
   step no longer exists in `release.yml` (PR #28), and this run empirically confirms
   its removal actually fixed the red -- not just that the workflow file changed.

3. **Artifact/local-build reproducibility confirmed** -- downloaded the run's `gem`
   artifact (`gh run download 32831263811 -n gem`):
   `openehr-rails-0.5.0.gem`, 197632 bytes, sha256
   `e07815bd1c86736403cbb558fec869fbe04666f695e6cc12a41dad9be77230e6`. Ran
   `bundle exec rake build` locally at the same tagged commit (`69db63f`, clean
   tree): `pkg/openehr-rails-0.5.0.gem`, same size, **identical sha256**. CI's
   built artifact and a local build from the same commit are byte-identical --
   confirms build reproducibility, not just "both builds succeeded."

RubyGems publish is next: per condition, that remains a deliberate human `gem push`
step (established operating model, `docs/backlog.md` "Release automation"), not
something this session executes -- the sha256 above is the value to check the
locally-published gem against before/after `gem push`, and after publish confirms.
Awaiting that confirmation before the final backlog/CHANGELOG follow-up (condition 5)
and returning to dormancy.

## R9 -- RubyGems publish confirmed, backlog updated, dormant

User reported publish complete. Verified directly rather than trusting the report at
face value: queried `https://rubygems.org/api/v1/versions/openehr-rails.json`.
`openehr-rails` `0.5.0` is listed, `created_at: 2026-08-25T09:26:15.342Z`, and its
published `sha` field (`e07815bd1c86736403cbb558fec869fbe04666f695e6cc12a41dad9be77230e6`)
matches R8's CI-artifact and local-build sha256 exactly -- full chain confirmed
byte-identical: local build == CI artifact == published gem.

Added a bullet to `docs/backlog.md`'s "CI status" section recording the `v0.5.0`
tag run (first fully-green tag-push run, confirming PR #28's release-path fix)
and the three-way sha256 match including the now-confirmed RubyGems listing.
Verified `CHANGELOG.md`'s `[0.5.0] - 2026-08-25` section is correctly finalized
with a fresh empty `[Unreleased]` above it -- no further edit needed. Full suite
re-confirmed green (275 examples, 0 failures) before this commit.

**Issue #30 fully closed out**: filed, designed, implemented (Codex + independent
review), merged, released as `0.5.0`, published to RubyGems, and the upstream
knowledge shared back to `skoba/openehr-ruby#31`. `anlage`'s FSH export
(`skoba/anlage#17`) can now pick up `field[:value_set_uri]`/`field[:code_bindings]`
via a normal `bundle update` -- the consumption prerequisite flagged in R7 is
satisfied. Returning to dormancy.

# Institutionalization log

Terse, chronological record of the ticket-driven-workflow institutionalization task
(openehr-rails#29, same intent as openehr-ruby#35). One entry per step; not a design
doc, not a status board -- just what happened, with evidence (issue/commit/PR
references). No chat report per step; a single bundled report goes to the user at
completion.

## R1 -- Self-filing (Step 0)

Filed openehr-rails#29 ("Institutionalize ticket-driven workflow: CLAUDE.md section +
issue templates"), cross-referencing openehr-ruby#35 (`Refs skoba/openehr-ruby#35`).
Body mirrors #35's Motivation/Current behavior/Proposed behavior/Acceptance
criteria/Compatibility notes shape, plus this repo's own
`lib/generators/**/templates/` clarification (not present in #35, since openehr-ruby
has no generator-output surface). This log created in the same pass.

## R2 -- CLAUDE.md section (Step 1)

Added "Ticket-driven workflow" section to `CLAUDE.md`, positioned right after
`## Principle` (before `## Working with implementation agents`), mirroring
openehr-ruby's adjacency of its "Development style" and "Contribution workflow"
sections. Covers all 5 points from #29's acceptance criteria: Issue-required
threshold (+ the `lib/generators/**/templates/` clarification), spec-verifiable
Acceptance criteria, the 3 resolution kinds (bug/enhancement/pin), the
1issue=1branch=1PR + `Fixes #N` reaffirmation, and the plan-doc-issue-number-first
convention.

## R3 -- Issue templates (Step 2)

Created `.github/ISSUE_TEMPLATE/` (did not exist before): `bug_report.md` (7
headings: Summary/Environment/Reproduction/Expected vs Actual/Root cause/Proposed
fix/Acceptance criteria; Environment section's version examples transcribed from the
actual current gemspec/version.rb: openehr-rails 0.4.1, `openehr ~> 2.3`), `enhancement.md`
(5 headings: Motivation/Current behavior/Proposed behavior/Acceptance
criteria/Compatibility notes, with the compatibility checklist explicitly listing
generator-output impact per the same clarification), and `config.yml`
(`blank_issues_enabled: true`). YAML frontmatter and config.yml validated with
`YAML.load`.

## R4 -- Landed (Step 3)

Committed everything (CLAUDE.md, docs/backlog.md, this log, .github/ISSUE_TEMPLATE/)
directly to `master` in one commit, `af94d55`, `Fixes #29` -- confirmed closed
(`closedAt: 2026-08-23T03:57:03Z`). `docs/backlog.md` gained a "December public
release prep" section: issue templates marked done, and the demo_assets README
follow-up recorded as newly noted here (no prior record of that deferral was found
anywhere in this repo's docs -- flagged rather than asserted as already recorded).
No branch/PR used, per the task's explicit instruction (small docs-only bootstrapping
task, semver-neutral) -- not a deviation from the 1issue=1branch=1PR convention just
institutionalized, which governs code changes going forward from here.

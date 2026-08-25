---
name: Bug report
about: Something behaves incorrectly
title: ''
labels: bug
assignees: ''
---

## Summary

<!-- One or two sentences: what's wrong. -->

## Environment

- `openehr-rails` version: <!-- e.g. 0.4.1 -->
- `openehr` version: <!-- e.g. ~> 2.3 -->
- Rails version: <!-- e.g. 8.1 -->
- Ruby version: <!-- e.g. 3.3, 3.4, 4.0 -->
- If the report involves an OPT/ADL file: the generating tool and its
  version (e.g. Better Archetype Designer / Ocean Template Designer 2.6 /
  ADL Workbench / LinkEHR / HMC).

## Reproduction

<!-- Minimal runnable code (a generator invocation, a snippet against a model, an
     .opt/.adl fixture) that reproduces the bug from a clean checkout. -->

```ruby
```

## Expected vs Actual

- Expected:
- Actual:

## Root cause

<!-- file:line, if known. Leave blank if not yet investigated -- explore/plan happens
     after filing, not before. -->

## Proposed fix

<!-- Optional at filing time; fill in once a plan exists. -->

## Acceptance criteria

<!-- Spec-verifiable. E.g.: -->
- [ ] A reproduction spec for this bug goes red on the current code, then green after
      the fix (see CLAUDE.md's "Ticket-driven workflow": bug = red-first).

<!-- semver: the StructureDefinition id / url / name / title change for every
     profile (visible output, Upgrade note) -> minor in 0.x terms. The ruling that
     scheduled this (R-20261124-16) named the release 0.9.1; settle at inventory. -->

### Changed
- **Upgrade note.** FHIR StructureDefinitions are qualified by their template, so two
  templates that use the same archetype with different constraints no longer produce
  the same profile: `id` is `openehr-<template slug>-<archetype slug>` (e.g.
  `openehr-bmi-calculation-observation-height-v2`, was
  `openehr-observation-height-v2`; an id longer than 64 characters keeps a prefix and
  ends in 8 hex digits of its sha256), `url` is
  `urn:openehr:<template_id>:<archetype_id>`, `name` is the id camelized
  (`OpenehrBmiCalculationObservationHeightV2`; the JSON `name` used to be the bare
  concept, `Height`, and disagreed with the FSH `Profile:` name) and `title` names the
  template. Files written by `--fhir` / `openehr:fhir_profile` under
  `app/fhir/profiles/` take the new ids as file names: regenerate them. Anything that
  references a profile by its old id or url must be updated. The constraints inside
  each profile are unchanged (#55, anlage upstream 23).
- `ProfileGenerator` (JSON) and `FshGenerator` take id, url, name and title from one
  place, `OpenehrRails::Fhir::ProfileIdentity`, so the two outputs cannot disagree
  (#55).

### Known limitations
- FHIR Observation *instance* ids still use the archetype-only slug, so two models
  sharing an archetype can produce the same instance id (#76).

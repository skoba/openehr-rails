### Fixed
- The FHIR facade no longer serves every entry as an Observation. An entry is
  served as the resource its StructureDefinition describes:
  `openEHR-EHR-EVALUATION.problem_diagnosis.v1` as a Condition (`category`
  carries the archetype coding; `code`, `onsetDateTime`, `recordedDate`,
  `abatementDateTime` and `verificationStatus` per the mapping table), Observation
  entries as before, and entries with no mapping (INSTRUCTION, ACTION, other
  EVALUATIONs, ...) not at all. The CapabilityStatement lists only what is
  served (#104).
- `POST /fhir/Observation` with the code of an entry served as another resource
  answers 422 instead of creating the record (#104).

### Added
- `GET /fhir/Condition?category=<archetype_id>&subject=<ref>` and
  `GET /fhir/Condition/:id`, for scaffolded models and runtime templates (#101)
  alike; read and search only (the CapabilityStatement lists no `create` for
  Condition, and `category`/`subject` as its search parameters). Coded values
  of runtime records carry the record's own text as `display` and its
  terminology as `system` (#104).

- Conditions carry `clinicalStatus` (required in FHIR R5), a value the facade
  sets rather than one from the record: `unknown` (as a null flavor) when the
  record has no date/time of resolution (at0030), `inactive` with
  `abatementDateTime` when it has one (at0030 covers resolution or remission,
  so not `resolved`; `inactive` satisfies con-3). System
  `http://terminology.hl7.org/CodeSystem/condition-clinical`. The generated
  StructureDefinition and FSH note this on `clinicalStatus` (comment only, no
  binding or fixed value) (#104).
- Condition date/time elements are FHIR dateTimes: a value with a time but no
  offset is read as UTC, as `Observation.effectiveDateTime` is, and missing
  seconds are filled in; valid values and dates stay as recorded (#104).

### Known limitations
- `Condition.verificationStatus` carries the archetype's local at-codes, which
  do not satisfy R5's required binding to `condition-ver-status`; at0003 →
  `recordedDate` is an approximation (both as decided for the profiles) (#104).

### Upgrade notes
- Problem-list records (problem_diagnosis) disappear from
  `GET /fhir/Observation` and appear at `GET /fhir/Condition`. A client that
  read them as Observations (`component[]`) must read Conditions instead. Records
  of other non-Observation entries without a mapping (INSTRUCTION, ACTION, ...)
  are no longer served at all, matching their profiles, which were never
  generated (#104).

<!-- semver: minor. The resource type served for an entry changes and an
endpoint is added (public API); Observation entries are unchanged
(serializer_spec unchanged, regression pin). -->

<!-- semver: minor. FieldExtractor's public output grows (new fields for INSTRUCTION
     entries and for any entry's protocol); scaffolds of such templates gain columns. -->

### Added
- `FieldExtractor` descends `activities`, `description` and `protocol`, so an
  `INSTRUCTION` entry has fields for the ELEMENTs under
  `activities[...]/description[...]` and `protocol[...]`, including the embedded
  CLUSTER roots there at any depth (a referral's `service_request`: 0 fields before,
  20 now). `ACTION.description` and every entry type's `protocol` come with the same
  change. `narrative`, `timing` and `action_archetype_id` are not ELEMENTs and yield
  no field (#47, anlage upstream 17).

### Changed
- **Upgrade note.** A template whose entries carry `protocol` leaves extracts more
  fields than before, so re-scaffolding it adds columns: e.g. `problem_list.opt`
  gains `problem_diagnosis_at0070` (最終更新日, under `protocol[at0032]`). Existing
  generated models are not touched. The FHIR profile for `problem_diagnosis` is
  unchanged: at0070 has no row in `TypeMap::ENTRY_ELEMENT_MAPS` and is left out.
- The FHIR generators now report an `INSTRUCTION` that has leaves through `#skipped`
  as "N leaves ... no row in `TypeMap::ENTRY_ELEMENT_MAPS`" instead of "no leaves";
  still no `ServiceRequest` profile is emitted (mapping rows: #35).

### Known limitations
- `Storable` cannot assemble a valid composition for an `INSTRUCTION` entry (nor for
  entries nested in a SECTION or fields under an embedded root): a model scaffolded
  from such a template must not be saved until the guard (#60) and the write-path
  fixes (#61, #62) land.

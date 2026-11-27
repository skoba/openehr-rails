# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.14.0] - 2026-11-27

> **Upgrade note.** No migration, and no dependency change. Two things change
> for an existing host app's FHIR facade (`/openehr/fhir`).
> (1) Records in the RM graph that no scaffolded model owns (committed through
> `/openehr/v1` or `Rm::CompositionCommitter`) are now served, for templates in
> the `OpenehrTemplate` registry or handed over with the new
> `OpenehrRails::Fhir.template_source`. A template that has a scaffolded model
> is still served by the model only (#101).
> (2) Problem-list records (problem_diagnosis) move from `GET /fhir/Observation`
> to `GET /fhir/Condition`, with a `clinicalStatus` the facade sets; records of
> other non-Observation entries without a mapping (INSTRUCTION, ACTION, ...)
> are no longer served, and `POST /fhir/Observation` with such a code answers
> 422 (#104).

### Added
- The FHIR facade (`/openehr/fhir`) serves records of templates registered
  at runtime: compositions in the RM graph that no scaffolded model owns
  (committed through `/openehr/v1` or `Rm::CompositionCommitter`). Search
  (`code`, `subject`), read by id, the CapabilityStatement and
  StructureDefinition answer for them through the same endpoints. Values
  are read from the RM graph with the same path walk Storable uses (#101).
- `OpenehrRails::Fhir.template_source`: a callable returning one
  `{ template_id:, opt: }` per template id, for a host app that keeps its
  templates outside the gem's `OpenehrTemplate` registry (the default):

  ```ruby
  # config/initializers/openehr.rb
  Rails.application.config.to_prepare do
    OpenehrRails::Fhir.template_source = lambda do
      Template.where(status: 'active').map { |t| { template_id: t.template_id, opt: t.source_xml } }
    end
  end
  ```

  A template id returned twice raises `OpenehrRails::Fhir::TemplateSourceError`
  (answered 500) instead of one being picked silently (#101).
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

### Changed
- `GET /fhir/StructureDefinition/:id` also finds a generated profile when the
  host has profile files under `app/fhir/profiles` for other templates (#101).
- The CapabilityStatement lists each archetype once in `supportedProfile`
  even when several templates use it (#101).

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

### Known limitations
- Runtime records are read with the fields of the template the source
  returns now. A record written with an older version of the template shows
  only the fields that version shares with the current one (#101).
- A composition whose uid is not a UUID has no valid FHIR id
  (`c<uuid hex>-<entry index>`) and is not served (#101).
- Where a template repeats an archetype root, values are read from its first
  instance, as `Storable.from_rm_composition` does (#101).
- `Condition.verificationStatus` carries the archetype's local at-codes, which
  do not satisfy R5's required binding to `condition-ver-status`; at0003 →
  `recordedDate` is an approximation (both as decided for the profiles) (#104).

## [0.13.0] - 2026-11-27

> **Upgrade note.** No migration, and no dependency change. One thing changes
> for an existing host app: `POST /v1/ehr` and `PUT /v1/ehr/:ehr_id` now answer
> 409 (with the existing `ehr_ids`) instead of 201 when an EHR already has the
> same `EHR_STATUS.subject` id, namespace pair. A client that created several
> EHRs for one subject gets 409 for the second one. EHRs without a full subject
> pair (anonymous) are not compared and can still be created repeatedly.
> Duplicates that already exist are not touched; the new
> `GET /v1/ehr?subject_id=...` reports them with 409 (#99).

### Added
- openEHR REST `GET /v1/ehr?subject_id=...&subject_namespace=...` (ITS-REST EHR
  API, "Get EHR by subject id"): returns the EHR whose `EHR_STATUS.subject`
  matches both parameters, in the same shape as `GET /v1/ehr/:ehr_id`, or 404
  when none does. Two answers are this implementation's own, because the
  specification does not cover them: several EHRs for one subject return 409
  with `{ "error": ..., "ehr_ids": [...] }` (oldest first) instead of one picked
  silently, and a missing or blank parameter returns 400 with `{ "error": ... }`.
  Access scope is `:rest_api`, as for the other REST endpoints (#95).

### Changed
- `PUT /v1/ehr/:ehr_id` refuses a second EHR for a subject in the same way as
  `POST` (409 with `ehr_ids`). The specification's 409 for this operation covers
  only an `ehr_id` already in use; extending it to the subject is this
  implementation's own handling, so the outcome does not depend on which
  endpoint was used. The `ehr_id`-in-use 409 is unchanged (`{ "error": ... }`
  only) (#99).

### Fixed
- openEHR REST `POST /v1/ehr` no longer creates a second EHR for a subject that
  already has one. When an EHR already has the same `EHR_STATUS.subject`
  id, namespace pair, it returns 409 with
  `{ "error": ..., "ehr_ids": [...] }` (the existing EHRs, oldest first, as in
  the 409 of `GET /v1/ehr?subject_id=...`), as the ITS-REST EHR API "Create
  EHR" requires. Before, it answered 201 (#99).

### Known limitations
- No database unique index backs the subject check (it would need a migration
  in every host app, and would fail where duplicates already exist), so two
  concurrent create requests for the same subject can both succeed (#99).

## [0.12.0] - 2026-11-27

> **Upgrade note.** No migration, and no dependency change. Three things change
> for an existing host app.
> (1) Templates with an embedded archetype root, a SECTION, a repeated entry or an
> INSTRUCTION now save instead of raising `UnsupportedTemplateShape` (#60). A
> model scaffolded with 0.11.0 or earlier still raises for a root or entry that
> repeats in its template, and asks for a re-scaffold: regenerate the model to
> get the new `root_chain` / `root_label` / `action_archetype_id` FIELD_MAP keys.
> (2) A `DV_DATE_TIME` read back from the RM graph (canonical JSON, REST GET,
> `to_rm`) is the string it was committed with, not a UTC instant. Rows written
> before 0.12.0 keep reading back as the UTC instant; AQL is unchanged.
> (3) The gem no longer packages `spec/`, `docs/`, `demo_assets/` or scripts.

### Added
- `Storable` saves INSTRUCTION entries. `narrative` (mandatory DV_TEXT) is built
  from the filled elements under the INSTRUCTION, in template order, as
  "label: value" (under an embedded root, "root name／label: value"), joined by
  a full-width semicolon (DV_TEXT cannot hold a line break); coded values use
  their display text, quantities "value units", date-times `YYYY-MM-DD HH:MM`.
  This is the rule anlage uses for form-built compositions. Each ACTIVITY gets
  `action_archetype_id`: the OPT's C_STRING pattern as `/pattern/`, else `/.*/`.
  An INSTRUCTION with no filled element is not written (#69).
- The RM graph keeps `ACTIVITY.action_archetype_id` (in the node's existing
  `extra` JSON column; no migration), and `rm_graph.to_rm` / the canonical
  serializer read it back. Graphs written before keep the `/.*/` approximation;
  the narrative was already stored and now holds the built text rather than
  falling back to the node name (#69).
- `Opt::FieldExtractor` fields carry `root_chain`: every archetype root from the
  entry down to the field, each as `[root_path, ordinal]`, where the ordinal is
  the document-order count among roots with that path. It tells which instance
  of a repeated root holds a field, which `instance_index` (per field path)
  cannot (#61). They also carry `root_label` (the template name of the nearest
  embedded root instance, e.g. 紹介元医療機関 / 紹介先医療機関) and, under an
  ACTIVITY, `action_archetype_id` (#69).
- The AQL console (`GET /query`) opens with a query filled in when the URL
  carries `q` (and optionally `query_parameters`, as a JSON string), so another
  page can link to it, e.g. with an EHR's `ehr_id` in the query. Opening the page
  does not run the query; the button still does. Values are HTML-escaped; each
  is taken only as a string of at most 10,000 characters, and the page says so
  when one is longer. Without these parameters the console is unchanged (#94).

### Changed
- `Storable::UNSUPPORTED_SHAPES` drops `:section` and `:instruction`, and gains
  `:repeated_entry`. A model scaffolded before `root_chain` (0.11.0 or earlier)
  whose template repeats an entry now refuses a value for that entry instead of
  merging the instances, and asks for a re-scaffold (#62). `:embedded_root`
  remains for roots such a model cannot place: models scaffolded before 0.9.0, or
  a root on the field's path that repeats in the template; its message now asks
  for a re-scaffold (#61). `openehr:scaffold` no longer warns about INSTRUCTION
  fields (#69).
- `Rm::Composition#to_rm` and `Rm::RmObjectBuilder.new` accept
  `normalize_date_times:` (default `false`). AQL still evaluates `DV_DATE_TIME`
  values as the normalized UTC instant, because openehr's
  `DvDateTime#magnitude` (2.7.0 and earlier) applies a positive UTC offset with
  the wrong sign; AQL switches to the committed string once a fixed openehr is the
  lower bound (#63, follow-up #92).
- The gem ships only what a host application runs: `lib/` (generator templates
  included), `app/`, `config/`, `README.md`, `CHANGELOG.md`, `LICENSE` and the
  gemspec. `spec/` (OPT fixtures), `docs/`, `doc/`, `demo_assets/`, scripts and
  CI/tooling files are no longer packaged. Measured on 0.11.0's tree: 201 -> 84
  files, 354,304 -> 80,384 bytes. The application template
  (`templates/openehr_template.rb`) is used from the repository URL and is not
  packaged either (#74).

### Fixed
- `Storable` saves values under an embedded archetype root (e.g. the analyte
  CLUSTER of a lab result) as an archetyped `CLUSTER` inside its entry, with
  `archetype_details`; `rm_graph.to_rm` rebuilds it. 0.9.0 refused such a save
  (`UnsupportedTemplateShape`, #60) because the write path used to emit a second,
  bogus entry. Templates without embedded roots write the same composition as
  before (#61).
- `Storable` saves entries nested in a SECTION inside a `SECTION` node under
  `content` (with `archetype_details`), and keeps two instances of one entry
  archetype as two entries (e.g. `clinical_synopsis` x2 in a referral);
  `rm_graph.to_rm` rebuilds them. 0.9.0 refused such a save because the write
  path dropped the SECTION and merged the instances (#62).
- Repeated entries directly under `content` (e.g. two `body_mass_index`
  OBSERVATIONs) are written as separate entries; before, the second instance
  overwrote the first one's element (#61, #62).
- A `DV_DATE_TIME` value read back from the RM graph keeps the ISO 8601 string it
  was committed with: partial precision (`2026-03-01`, `2026-03-01T10:00`) and the
  UTC offset (`+09:00`) are no longer lost. Canonical JSON (`to_canonical_hash`,
  the REST GET) and `Rm::Composition#to_rm` return it unchanged. Until now a
  date-only `2026-03-01` came back as the previous day's instant
  (`2026-02-28T15:00:00Z` with `Time.zone` at +09:00). The committed string is
  kept in the `DV_DATE_TIME` row's existing `text_value`; `datetime_value` stays
  the normalized instant used for SQL and ordering (#63).

### Known limitations
- Reading a repeated entry or root back with `from_rm_composition` still takes
  the first instance (#89).
- AQL returns `DV_DATE_TIME` values as the UTC instant (#92).
- A REST `GET` of a logically deleted composition still returns its body (#85).
- FHIR Observation *instance* ids still use the archetype-only slug (#76).

## [0.11.0] - 2026-11-26

> **Upgrade note.** Two things change for an existing host app.
> (1) Requires `openehr` `~> 2.6, >= 2.6.1` (was `~> 2.5`): a host app locked to
> openehr 2.5.x or 2.6.0 must update it together with this gem.
> (2) AQL no longer returns logically deleted compositions by default; pass
> `composition_scope: OpenehrRails::Rm::Composition.latest` to include them again.

### Changed
- Requires `openehr` `~> 2.6, >= 2.6.1`. With it, AQL reaches
  `c/context/start_time` (#46), `c/archetype_details/template_id` (#64) and
  `c/uid/value`, lifting the 0.9.0 and 0.10.0 known limitations on those paths (#83).
- The default `composition_scope` of `OpenehrRails::Aql::Executor.execute` (and
  `Aql::DatasetAdapter.build`) is now `Rm::Composition.latest.not_deleted`, so a
  composition deleted through the REST `DELETE /v1/ehr/:ehr_id/composition/:uid`
  is no longer returned. The engine's EHR screen (`/openehr/ehrs`) leaves such
  compositions out of its counts and timeline as well. A scaffolded record's
  `destroy` still purges its graph (#81, anlage upstream 28).

### Added
- `Rm::Composition.not_deleted` scope, and `Rm::CompositionCommitter.delete(uid:, ehr:)`,
  which the REST DELETE now uses (#81).

### Fixed
- `Composition#to_rm` rebuilds `archetype_details` (`archetype_id` from the root's
  `archetype_node_id`, `template_id`, `rm_version`) from the stored row; it used to
  be nil, so the template a record came from was unreachable. A root node id that
  is not a valid archetype id rebuilds with `archetype_details` nil, as before
  (#64, anlage upstream 25).
- A logical delete's Contribution is recorded as `deleted` (523), not `amendment`
  (250), and its version is created with lifecycle 523 in one step (#81).

### Known limitations
- A REST `GET` of a logically deleted composition still returns its body (#85).
- FHIR Observation *instance* ids still use the archetype-only slug (#76).

## [0.10.0] - 2026-11-25

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
- With openehr 2.6.0 or later (allowed by the unchanged `~> 2.5`), AQL reaches the
  composition context: `SELECT c/context/start_time/value` and a `WHERE` on it are
  answered, lifting the 0.9.0 limitation below. With openehr 2.5.x it still applies.
  `SELECT c/uid/value` is not answered yet under 2.6.0 (`unsupported path attribute
  "uid"`) (#46).

## [0.9.0] - 2026-11-24

> **Upgrade note.** Four things change for an existing host app.
> (1) Requires `openehr` `~> 2.5` (was `~> 2.3, >= 2.3.1`): a host app locked to
> openehr 2.4.x must update it together with this gem.
> (2) `FieldExtractor` output: a field under an embedded archetype root now has the
> root written `[archetype_id]` in its `path` and is named after its own archetype
> (`laboratory_test_analyte_at0001`, was `laboratory_test_result_at0001_2`); entries
> with `protocol` leaves and every `INSTRUCTION` extract more fields than before. A
> generated model keeps the `FIELD_MAP` it was generated with, so nothing moves until
> you re-scaffold; re-scaffolding such a template adds and renames columns. Code that
> reads `FieldExtractor#fields` at runtime sees the new paths and names immediately.
> (3) `Storable` now raises `OpenehrRails::Storable::UnsupportedTemplateShape` on save,
> and saves nothing, when a record holds a value for a field it cannot assemble into a
> valid composition (an entry nested in a `SECTION`, a field under an embedded root, an
> `INSTRUCTION`). Such saves used to succeed and store a malformed `rm_composition`.
> (4) FHIR `component` slice names follow the renamed fields.
> Also: a composition committed from canonical JSON **with** a `context` now answers
> `c/context/...` AQL paths with `unsupported path attribute` (as every
> `Storable`-saved composition already did) instead of a row holding `nil`; see Known
> limitations.

### Added
- `FieldExtractor` descends `activities`, `description` and `protocol`, so an
  `INSTRUCTION` entry has fields for the ELEMENTs under
  `activities[...]/description[...]` and `protocol[...]`, including the embedded
  CLUSTER roots there at any depth (a referral's `service_request`: 0 fields before,
  20 now). `ACTION.description` and every entry type's `protocol` come with the same
  change. `narrative`, `timing` and `action_archetype_id` are not ELEMENTs and yield
  no field (#47, anlage upstream 17).
- Fields carry `root_path` (path of the nearest embedded root, else of the entry) and
  `instance_index` (0-based document-order ordinal among the template's fields sharing
  the same `path`), so `[path, instance_index]` identifies a field even when the same
  archetype is embedded twice side by side (a referral's requester / receiver
  organisation) or an entry archetype repeats. Root names and name-predicate paths
  wait for per-root terms upstream (openehr-ruby#58) (#57).
- DV_QUANTITY fields carry `units_list`, every unit the OPT allows in OPT order;
  `units` stays the first one (#57).
- Fields carry `min_occurrences`, the ELEMENT's own occurrences lower bound (0 when
  unconstrained). `required` keeps its meaning ("entry mandatory and element
  mandatory"), so under an optional entry a 1..1 element is
  `required: false, min_occurrences: 1`: mandatory if the entry is written at all.
  Generated validations are unchanged; validating that conditional requirement is
  #65 (#58, anlage upstream 20).

### Changed
- `FieldExtractor` writes an embedded archetype root in a field's `path` by its
  archetype id instead of its at-code, and names fields under such a root after their
  own archetype: `<own concept>_<label slug, else at-code>` (never the bare concept).
  For `lab_result_report_reduced.opt`: `.../items[at0010]/items[at0001]/value` becomes
  `.../items[openEHR-EHR-CLUSTER.laboratory_test_analyte.v1]/items[at0001]/value`.
  Paths now match RM data paths and AQL. Fields owned by the entry itself, and
  templates without embedded roots, are unchanged (#57, anlage upstream 22).
- A template whose entries carry `protocol` leaves extracts more fields: e.g.
  `problem_list.opt` gains `problem_diagnosis_at0070` (最終更新日, under
  `protocol[at0032]`). The FHIR profile for `problem_diagnosis` is unchanged: at0070
  has no row in `TypeMap::ENTRY_ELEMENT_MAPS` and is left out (#47).
- The FHIR generators report an `INSTRUCTION` that has leaves through `#skipped` as
  "N leaves ... no row in `TypeMap::ENTRY_ELEMENT_MAPS`" instead of "no leaves";
  still no `ServiceRequest` profile is emitted (mapping rows: #35) (#47).
- `openehr:scaffold` prints a warning listing the fields the generated model cannot
  save yet (#60).
- Requires `openehr` `~> 2.5`. `OpenehrRails::Opt::Parser` no longer reads OPT
  `term_bindings` itself: openehr 2.5.0 does (openehr-ruby#31), and the interim bypass
  is removed (#59).

### Fixed
- `OpenehrRails::Storable` no longer writes a malformed composition for the template
  shapes it cannot assemble: saving a value for a field of an entry nested in a
  `SECTION`, of an embedded archetype root or of an `INSTRUCTION` raises
  `UnsupportedTemplateShape`, naming the shape, the fields and the tracking issue
  (#62, #61, #69), and saves nothing. Records that leave those fields empty, and
  models of templates without these shapes, save exactly as before. Models generated
  before 0.9.0 are covered too (#60).
- An OPT embedding the same archetype more than once no longer yields each term
  binding once per occurrence: `code_bindings` holds one entry per binding, so the
  FHIR `code.coding` slices are not duplicated. Two behaviours follow upstream and
  differ from the removed bypass: a binding item without a `terminology_id` is no
  longer completed from the `term_bindings` element's `terminology` attribute, and
  when roots of the same archetype carry *different* bindings the last root wins
  instead of their union (#59).
- `CompositionCommitter` / `GraphBuilder` persist a canonical composition's
  `context.start_time` (into `context_start_time`) and `context.setting` (into the
  already-existing `setting_code` / `setting_value` columns); they were dropped unless
  the caller passed `context_start_time:`. An explicit `context_start_time:` still
  wins. `RmObjectBuilder` rebuilds the stored setting instead of always `other`
  (#46, proposals 1-2; anlage upstream 16).

### Known limitations
- `Storable` cannot yet write entries nested in a `SECTION` (#62), fields under an
  embedded archetype root (#61) or `INSTRUCTION` entries (#69); it refuses them as
  described above. Committing a canonical composition through
  `Rm::CompositionCommitter` is unaffected.
- `SELECT c/context/start_time/value` (and `c/context/setting/...`) is not answerable
  yet: the openehr AQL path evaluator (2.5.0 included) cannot navigate `EVENT_CONTEXT`
  and raises `unsupported path attribute "start_time"` as soon as a composition has a
  context. The values are stored and rebuilt by `to_rm`; querying them waits for an
  openehr release. (openehr 2.6.0 lifts this for `start_time`; see 0.10.0.)
- `context.other_context` is not persisted, and `CanonicalSerializer` does not emit
  `context` yet (#46 stays open for both).

## [0.8.0] - 2026-10-12

> **Upgrade note.** A stored Composition holding a `SECTION` or an `INSTRUCTION`
> (with its `ACTIVITY`s) now reads back through `to_rm` and AQL; the ones 0.7.1
> skipped with `openehr-rails AQL: skipping composition uid=...` are exactly the
> ones that become visible, so query row counts can grow. Two injected defaults
> are approximations until a later release persists them as columns: an
> INSTRUCTION without a stored narrative reads back with its node name as
> `narrative`, and every ACTIVITY with `action_archetype_id` `'/.*/'`.

### Added
- `RmObjectBuilder` rebuilds `SECTION`, `INSTRUCTION` and `ACTIVITY` nodes (and
  every CARE_ENTRY's `protocol`), so compositions holding them -- a referral's
  `service_request` with its requester/receiver under `protocol[...]`, entries
  nested in a `SECTION` -- become readable through `to_rm` and queryable by AQL
  instead of being skipped with the 0.7.1 warning (#45). Two values are
  **approximations** because the graph does not carry them yet: an INSTRUCTION
  without a stored narrative gets its node name as `narrative`, and every
  ACTIVITY gets `action_archetype_id` `'/.*/'` (any ACTION archetype). Both will
  be persisted as columns in a later release. `ACTION`, `ITEM_SINGLE` and
  `ITEM_TABLE` are still unsupported (skipped with the warning).
- `FieldExtractor` fields carry `rm_type_alternatives`: every value type the OPT
  allows for the ELEMENT, in OPT order (e.g. `["DV_TEXT", "DV_CODED_TEXT"]` for
  `problem_diagnosis` at0002). Additive; the chosen `rm_type` is unchanged. Lets a
  host app tell an OR-constrained coded text (free text allowed) from a coded-only
  one instead of rendering an empty select (#52, anlage #33).

### Fixed
- An entry with no extracted leaves (today every `INSTRUCTION`, see #47) no
  longer gets a profile consisting of the archetype `code` rules and an empty
  `component` slicing header; it is skipped and reported through `#skipped`
  with a message saying the entry has no leaves, whatever its resource (#49).

## [0.7.1] - 2026-09-25

> **Upgrade note.** AQL now skips a stored composition that holds an RM type
> `RmObjectBuilder` cannot rebuild, with a warning
> (`openehr-rails AQL: skipping composition uid=...`), instead of failing every
> query in the store. No host-app change is needed; if that line appears in
> your log, the composition is a #45 case (SECTION / INSTRUCTION / ACTIVITY
> read-back, next minor release).

### Fixed
- A single-leaf entry mapped to a resource other than `Observation` and without a
  `TypeMap::ENTRY_ELEMENT_MAPS` row no longer produces `<Resource>.value[x]`, which
  `Condition`/`ServiceRequest`/`Procedure`/`Encounter` do not have; it is skipped and
  reported through `#skipped` like the multi-leaf case since 0.7.0 (#38). The
  `UnsupportedProfileError` message now names both missing elements.
- AQL no longer fails for the whole store when one stored composition cannot be
  rebuilt as RM objects (a node type outside `RmObjectBuilder::TYPE_CLASSES`,
  such as `SECTION`/`INSTRUCTION`, or an RM constructor rejecting stored data).
  `DatasetAdapter` now warns (`Rails.logger` when present, else stderr), naming
  the composition uid and the cause, and skips that composition; queries on the
  rest of the store return their rows. `RmObjectBuilder` raises
  `OpenehrRails::Rm::UnsupportedRmTypeError` (composition uid, node path,
  rm_type) instead of an accidental `NoMethodError` (#44).

## [0.7.0] - 2026-09-10

> **Upgrade note.** Regenerate `app/fhir/profiles/*.json`. `Condition.component`
> slices are gone; anything reading them must move to the mapped elements
> (`category` slice `ckm`, `code`, `onsetDateTime`, `recordedDate`,
> `abatementDateTime`, `verificationStatus`), and an entry with no mapping onto
> a non-`Observation` resource now appears in the generator's `#skipped` list
> instead of producing a profile.

### Changed
- **Breaking for consumers of generated FHIR profiles.** `EVALUATION` entries no
  longer produce `Condition.component` slices, which FHIR R5 `Condition` does not
  have. Each leaf now maps onto the real `Condition` element that means the same
  thing — `code` (bound to the leaf's value set), `onsetDateTime`,
  `recordedDate`, `abatementDateTime`, `verificationStatus` — and the archetype
  anchor moves from `Condition.code` to a `Condition.category` slice (`ckm`,
  `1..1`, pattern-discriminated on `$this`, so an instance keeps room for its
  other categories), since `code` is now the diagnosis itself. `recordedDate`
  carries an `ElementDefinition.comment` stating that it approximates at0003
  (date/time clinically recognised). `ProfileGenerator` (JSON) and
  `FshGenerator` generate from one table in `TypeMap`, so the two outputs cannot
  disagree. Generated FSH for `problem_list.opt` goes from 29 Sushi errors to 0.
  Host apps must regenerate cached `app/fhir/profiles/*.json`; anything reading
  the old `Condition.component` slices must be updated (#33). Currently mapped:
  `openEHR-EHR-EVALUATION.problem_diagnosis.v1`. A multi-leaf entry mapped to
  `ServiceRequest`/`Procedure`/`Encounter` without a mapping-table row is now
  skipped and reported (see Added) instead of producing `component` constraints
  those resources do not have; its mapping table remains reserved as #35.
- Value-set canonicals on mapped leaves no longer carry OPT's `terminology:`
  prefix, in either output.

### Added
- `ProfileGenerator#skipped` and `FshGenerator#skipped`: the entries left out of
  `#profiles` / `#to_fsh_files`, each as an
  `OpenehrRails::Fhir::UnsupportedProfileError` (`archetype_id`,
  `resource_type`, `leaf_count`) in template order. An entry is skipped when it
  has more than one leaf, maps to a resource without `component`, and has no row
  in `TypeMap::ENTRY_ELEMENT_MAPS`; the rest of the template still generates.
  `rails g openehr:fhir_profile` and `openehr:scaffold --fhir` print each skip
  (#33).

### Removed
- `TypeMap.value_element`, dead since it was added — its ternary returned the
  same string on both branches and nothing called it. Its intended
  resource-type branch is now the mapping table (#33).

### Fixed
- `templates/openehr_template.rb` pins `json < 3` in the generated app's
  `Gemfile`. `json` 3.0 (2026-09-08) changed `JSON.parse`'s arity and
  `ActiveSupport::JSON.decode` as of activesupport 8.1.3.1 still passes options
  positionally, so a freshly generated host app failed at `db:seed` on its first
  json-column write (`ArgumentError: wrong number of arguments (given 2, expected
  1)`). Temporary: remove once a Rails patch release carries the fix. This
  repo's own `Gemfile` and `script/build_demo.sh` carry the same dev-only pin.
- `release:check` now fails when a tag matching the gemspec version exists and
  `HEAD` is not that tag's commit. `gem.files` comes from `git ls-files`, so a
  gem built at a later commit ships different bytes under the same version
  number — the defect that let 0.6.0 be published as a `master`-HEAD build
  (#34). The check stays silent when the version has no tag yet, so ordinary
  pre-release development is unaffected.

## [0.6.0] - 2026-08-26

> **Published artifact note.** The gem published to RubyGems for this version
> was built from `master` HEAD rather than the `v0.6.0` tag, so it contains the
> tagged tree plus two documentation files added after the tag
> (`docs/design/multi-leaf-non-observation-plan.md`, and this project's
> `docs/reports/fsh-generator-log.md` carrying its R6 entry). `lib/` is
> byte-identical to the tag artifact and version, runtime dependencies and
> `required_ruby_version` are unchanged, so the published gem is functionally
> identical to what CI built and verified at the tag; it was accepted rather
> than yanked. Published sha256
> `223e3b3897f85c38eaffe7ea39bd7c2acf4c5de9cab7d50fe38f754ff9d65db6`; tag-build
> sha256 `08cdd14ab1f3890b0c6b5f0ae0d5ca55615f0b4874ed5efb0cd4d7bda9e573ca`.
> Full measurements: `docs/reports/fsh-generator-log.md` R8. Prevention:
> `skoba/openehr-rails#34`.

### Added
- `OpenehrRails::Fhir::FshGenerator` renders one FHIR Shorthand profile per
  openEHR entry, including metadata, archetype codes, value constraints,
  component slicing, quantity units, fixed terminology codes, and required
  external value-set bindings. Observation-mapped output is Sushi-verified;
  multi-leaf non-Observation entries have a known structural gap tracked as #33.

### Changed
- `FshGenerator` no longer depends on `active_support/core_ext/string`; the
  three String helpers it used are now small plain-Ruby private methods,
  verified byte-identical output. Restores the Rails-independence this class
  was designed for (see `anlage`'s `docs/design/fsh-plan.md`), so it can move
  wholesale to a future satellite gem without a Rails dependency riding along.

## [0.5.0] - 2026-08-25

### Added
- `FieldExtractor` fields now always include `value_set_uri` for external
  `C_CODE_REFERENCE` value sets and `code_bindings` for ontology-level fixed-code
  bindings. `OpenehrRails::Opt::Parser` temporarily enriches OPT terminology objects
  with `term_bindings` until `skoba/openehr-ruby#31` is available upstream.

### Fixed
- `ProfileGenerator` now emits a required FHIR `binding.valueSet` for
  `DV_CODED_TEXT` fields constrained by `C_CODE_REFERENCE`; these fields previously
  received no binding. Existing local-code-list bindings remain strength-only. Host
  applications must regenerate cached `app/fhir/profiles/*.json` files to receive
  the new bindings.
- For multi-alternative `value` constraints, `FieldExtractor` now prefers a
  `C_CODE_REFERENCE`-backed alternative. This can change the extracted `rm_type` and
  scaffold column behavior from `DV_TEXT` to `DV_CODED_TEXT` for affected templates.

### Changed
- Raised the `openehr` dependency floor to 2.3.1 because 2.3.0 cannot parse
  `C_CODE_REFERENCE` constraints (`skoba/openehr-ruby#30`).

## [0.4.1] - 2026-08-22

Errata: this release includes minor-level changes (Ruby >= 3.3 requirement,
OpenehrRails namespace consolidation) and should be treated as a minor release
when upgrading from 0.4.0.

### Fixed
- `FieldExtractor` now resolves embedded-archetype element terminology in the nearest
  enclosing `C_ARCHETYPE_ROOT`, preventing both silent at-code collisions with the outer
  entry and fallback to raw at-codes when the outer terminology lacks a definition.
  Embedded fields' `archetype_id` and generated FHIR profile coding now use that same
  owning archetype id.

### Changed
- Upgraded the `openehr` runtime dependency to 2.3.0 (from 2.1.0; gemspec
  constraint raised from `~> 2.0` to `~> 2.3`). `OpenehrRails::Aql::QueryValidator`
  no longer rejects four AQL constructs that now execute correctly as of
  openehr 2.3.0: `LIKE` (AQL's glob syntax -- `*`/`?`, not SQL's `%`/`_`),
  `MATCHES` against a literal value list, `CONTAINS` with a
  standardPredicate/nodePredicate (e.g. `[at0004]`, not just an archetype
  predicate), and a `SELECT` mixing an aggregate and a plain column (implicit
  `GROUP BY`). Queries using these constructs, previously rejected with
  `OpenehrRails::Aql::UnsupportedFeature`, now execute. `MATCHES` against a
  `TERMINOLOGY(...)` value-set expansion is still rejected (no
  terminology-server value-set lookup is wired up). Also picks up the
  `openehr` 2.2.0 fixes for `SELECT TOP` and the EHR-root predicate (both
  previously silently ignored at execution) and the `Factory.create('COMPOSITION', ...)`
  `NoMethodError` fix in 2.3.0.
- Upgraded the `openehr` runtime dependency to 2.1.0 (from 2.0.2). Fixes
  two AQL execution bugs (`SELECT TOP` and the EHR-root predicate were
  both silently ignored at execution rather than raising), adds RM 1.1.0
  attributes (`DV_MULTIMEDIA.size`, `ELEMENT.null_reason`) and DV_DURATION
  arithmetic, and fixes a `DvAmount#+/-/-@` bug affecting `DvProportion`.
  No openehr-rails code changes were needed for the AQL fixes --
  `OpenehrRails::Aql::QueryValidator` never explicitly guarded either
  construct.
- **Raised the minimum supported Ruby version from 3.0 to 3.3**, dropping
  Ruby 3.2 from the CI matrix. This follows the `openehr` gem itself
  raising its own minimum to Ruby 3.3 in 2.1.0 (Ruby 3.2 is past its own
  upstream EOL).
- Consolidated on `OpenehrRails` as the sole module name, removing the
  vestigial `OpenEHR::Rails` (previously held only the gem's `VERSION`
  constant, now moved to `OpenehrRails::VERSION`) and an unused empty
  `Openehr::Rails` stub. No public API changed -- `OpenehrRails` was
  already the real, load-bearing namespace throughout the engine and the
  only one ever referenced by host-app-facing docs or generated code.

## [0.4.0] - 2026-08-13

### Added
- `OpenehrRails.authenticate_with`: a pluggable authentication hook, run
  as a `before_action` ahead of every engine action (admin UI, AQL
  console, patient timeline, the `/v1` openEHR REST API, and the `/fhir`
  facade). Host apps wire in their own mechanism (Devise, HTTP token,
  anything) with the controller as context. Per-surface differentiation
  via `openehr_access_scope` (`:admin`/`:rest_api`/`:fhir`).
- `OpenehrRails.allow_unauthenticated_access`: explicit opt-out for
  intentionally-open deployments.

### Changed (behavior change -- read before upgrading)
- **The engine now denies all requests with `403 Forbidden` outside the
  `development` and `test` environments unless `authenticate_with` or
  `allow_unauthenticated_access` is configured.** Previously every
  engine route (including the full openEHR REST API and the FHIR
  facade's create endpoint) was open with no access control whatsoever.
  Apps running 0.3.0 in production must configure one of the two before
  upgrading, or the engine will start responding 403 to everything.
- `RemoteFetcher` now also rejects loopback/private/link-local (including
  cloud metadata) addresses, both on the initial URL and on every
  redirect hop, closing an SSRF gap (previously only the URL scheme was
  validated).
- Every generic `rescue_from StandardError` handler across the engine's
  controllers now logs the exception (class, message, and a short
  backtrace) via `Rails.logger` before responding -- previously errors
  were rendered to the client and left no server-side trace at all.

## [0.3.0] - 2026-08-13

### Added
- `rails g openehr:scaffold`/`openehr:fhir_profile` now accept an OPT URL in
  place of a local path, via a new `OpenehrRails::Opt::RemoteFetcher`
  (redirect-following, timeout- and size-bounded HTTP(S) fetch that
  validates the response actually parses as an operational template).
- Admin UI (`/openehr`) gained a URL-import field (`OpenehrRails::TemplateImporter`),
  the URL counterpart to the existing drag & drop upload.
- AQL query support: `OpenehrRails::Aql` (dataset adapter, query validator,
  executor) and a `Model.aql(query, params:)` scope on every scaffolded
  model, plus a browser AQL console at `/openehr/query`.
- openEHR REST API surface at `/openehr/v1`: `EHR`, `EHR_STATUS`,
  `COMPOSITION` (create/read/update/delete with optimistic concurrency),
  and `QUERY` (AQL).
- Patient timeline UI at `/openehr/ehrs` (per-EHR composition history,
  grouped by date, with version history disclosure).
- Docker: `docker/demo.Dockerfile` + `docker/docker-compose.yml` run the
  full demo app in a container with no local Ruby/Rails install needed;
  `.devcontainer/` for gem development itself.
- `templates/openehr_template.rb`: a Rails application template
  (`rails new myehr -m <url>`) that wires up a brand new app with
  openehr-rails end to end, optionally scaffolding the same 3 sample
  templates as the demo. `script/build_starter.sh` wraps it into a
  standalone repo (README + CI) suitable for a GitHub template repository.
- CI matrix expanded to Ruby 3.2/3.3/3.4/4.0 x Rails 7.2/8.0/8.1
  (`gemfiles/rails_{7_2,8_0,8_1}.gemfile`), plus a demo-smoke job that
  builds the demo app and runs its generated request specs end to end.
- `LICENSE` file (Apache License 2.0, matching the gemspec's declared
  license -- previously declared but not actually included in the repo).

### Changed
- Upgraded the `openehr` runtime dependency from `~> 1.3.0` to `~> 2.0`
  (currently resolves to 2.0.2).
- `gem.license` corrected to the valid SPDX identifier `Apache-2.0`
  (was the non-SPDX string `"Apache 2.0"`).
- Added `gem.metadata` (`source_code_uri`, `changelog_uri`,
  `bug_tracker_uri`, `rubygems_mfa_required`) and dropped the deprecated
  `gem.test_files` assignment.

### Fixed
- `OpenehrRails::Rm` was never `require`d by `lib/openehr_rails.rb`,
  silently disabling the entire RM persistence layer (typed node graph,
  AQL, versioning) in any real host application -- it only appeared to
  work in this gem's own test suite because the spec support file
  required it separately. This was the most significant bug found during
  the 2.0 upgrade work.
- `OpenehrRails::Opt::Parser`'s raw-content-vs-path detection didn't
  account for a leading UTF-8 BOM, so any BOM-prefixed OPT (common in
  real-world exports) misdetected as a file path and crashed. Affected
  every raw-content caller (`TemplateUploader`, `TemplateRegistry`,
  `Fhir::ProfileRepository`, `RemoteFetcher`), not just one code path.
- `RmObjectBuilder#build_composition` never set `uid:`, so
  `SELECT c/uid/value` always returned nil.
- `EventContext#setting` used a raw `CODE_PHRASE` where openehr 2.0
  requires a `DV_CODED_TEXT`.

### Removed
- Legacy ADL-archetype-only generators (`model`/`controller`/`migration`/
  `helper`/`assets`/`i18n`/`template`/`template_model`, and their shared
  `Openehr::Generators::ArchetypedBase`). OPT is now the only supported
  scaffolding input format; `OpenehrTemplate.from_adl_file` (ADL
  *registration*, not scaffolding) is unaffected.
- The `ckm_client` gem dependency (only used by the removed legacy
  generators).

## [0.2.2] and earlier

Predates this changelog. See `git log` for history back to the project's
first commit in 2012.

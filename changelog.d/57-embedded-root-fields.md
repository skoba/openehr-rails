<!-- semver: minor. Path and name of fields under an embedded archetype root change;
     three additive keys. -->

### Changed
- **Upgrade note.** `FieldExtractor` writes an embedded archetype root in a field's
  `path` by its archetype id instead of its at-code, and names fields under such a
  root after their own archetype: `<own concept>_<label slug, else at-code>` (never
  the bare concept). For `lab_result_report_reduced.opt`:
  `.../items[at0010]/items[at0001]/value` becomes
  `.../items[openEHR-EHR-CLUSTER.laboratory_test_analyte.v1]/items[at0001]/value`, and
  `laboratory_test_result_at0001_2` becomes `laboratory_test_analyte_at0001`. Paths now
  match RM data paths and AQL. Fields owned by the entry itself, and templates without
  embedded roots, are unchanged. A generated model keeps the `FIELD_MAP` it was
  generated with; re-scaffolding such a template renames those columns. FHIR
  `component` slice names are derived from field names and change with them (#57,
  anlage upstream 22).

### Added
- Fields carry `root_path` (path of the nearest embedded root, else of the entry) and
  `instance_index` (0-based document-order ordinal among the template's fields sharing
  the same `path`), so `[path, instance_index]` identifies a field even when the same
  archetype is embedded twice side by side (a referral's requester / receiver
  organisation) or an entry archetype repeats. Root names and name-predicate paths
  wait for per-root terms upstream (openehr-ruby#58) (#57).
- DV_QUANTITY fields carry `units_list`, every unit the OPT allows in OPT order;
  `units` stays the first one (#57).

### Fixed
- `Storable` saves values under an embedded archetype root (e.g. the analyte
  CLUSTER of a lab result) as an archetyped `CLUSTER` inside its entry, with
  `archetype_details`; `rm_graph.to_rm` rebuilds it. 0.9.0 refused such a save
  (`UnsupportedTemplateShape`, #60) because the write path used to emit a second,
  bogus entry. Templates without embedded roots write the same composition as
  before (#61).

### Added
- `Opt::FieldExtractor` fields carry `root_chain`: every archetype root from the
  entry down to the field, each as `[root_path, ordinal]`, where the ordinal is
  the document-order count among roots with that path. It tells which instance
  of a repeated root holds a field, which `instance_index` (per field path)
  cannot (#61).

### Upgrade note
- Models scaffolded with 0.9.0 to 0.11.0 save embedded-root values without
  regeneration, unless a root on the field's path repeats in the template; those,
  and models scaffolded before 0.9.0, still raise `UnsupportedTemplateShape`
  (shape `:legacy_root`, previously `:embedded_root`) and need a re-scaffold.

<!-- semver: minor. A save that raised now succeeds, FIELD_MAP gains a key, and
     the guard's shape symbol is renamed (:embedded_root -> :legacy_root). -->

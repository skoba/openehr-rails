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
- `Opt::FieldExtractor` fields carry `root_label` (the template name of the
  nearest embedded root instance, e.g. 紹介元医療機関 / 紹介先医療機関) and, under an
  ACTIVITY, `action_archetype_id` (#69).

### Changed
- `Storable::UNSUPPORTED_SHAPES` drops `:instruction`: `openehr:scaffold` no
  longer warns about INSTRUCTION fields, and saving them no longer raises (#69).

<!-- semver: minor. Saves that raised now succeed; FIELD_MAP gains keys
     (additive); the graph stores a value it used to drop. -->

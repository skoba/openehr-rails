### Fixed
- `Storable` saves entries nested in a SECTION inside a `SECTION` node under
  `content` (with `archetype_details`), and keeps two instances of one entry
  archetype as two entries (e.g. `clinical_synopsis` x2 in a referral);
  `rm_graph.to_rm` rebuilds them. 0.9.0 refused such a save
  (`UnsupportedTemplateShape`, #60) because the write path dropped the SECTION
  and merged the instances (#62).
- Repeated entries directly under `content` (e.g. two `body_mass_index`
  OBSERVATIONs) are written as separate entries; before, the second instance
  overwrote the first one's element (fixed by the `root_chain` grouping of #61,
  noted here).

### Changed
- `Storable::UNSUPPORTED_SHAPES` drops `:section` and gains `:repeated_entry`:
  a model scaffolded before `root_chain` (0.11.0 or earlier) whose template
  repeats an entry now refuses a value for that entry instead of merging the
  instances, and asks for a re-scaffold (#62).

### Known limitation
- Reading a repeated entry or root back with `from_rm_composition` still takes
  the first instance (#89).

<!-- semver: minor. Saves that raised now succeed; a legacy FIELD_MAP with a
     repeated entry now raises where it used to write merged (malformed) data;
     the guard's shape set changes. -->

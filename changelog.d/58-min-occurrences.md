<!-- semver: minor (additive public output). -->

### Added
- `FieldExtractor` fields carry `min_occurrences`, the ELEMENT's own occurrences lower
  bound (0 when unconstrained). `required` keeps its meaning ("entry mandatory and
  element mandatory"), so under an optional entry a 1..1 element is
  `required: false, min_occurrences: 1`: mandatory if the entry is written at all.
  Generated validations are unchanged; validating that conditional requirement is
  #65 (#58, anlage upstream 20).

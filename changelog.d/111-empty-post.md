### Fixed
- `POST /fhir/Observation` with a resource that maps to no value (for example a
  multi-leaf archetype such as body_mass_index sent with `valueQuantity` alone,
  without `component[]`) is refused with 422 and an OperationOutcome naming why,
  before anything is created. It used to create a record with every value nil
  and then answer 400. A single-leaf POST (height) is unchanged (#111).

semver: patch. A bug fix; the only response that changes is the one for a
request that already failed (400 → 422), and it no longer leaves an empty record.

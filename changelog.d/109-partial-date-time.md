### Fixed
- A DV_DATE_TIME or DV_DATE of reduced precision (`2026`, `2026-11`; for a
  date-time also `2026-11-27T09`, `2026-11-27T09:30`) is stored in the RM graph.
  A year or year-month value used to raise `ArgumentError` (DV_DATE_TIME) or
  fail validation (DV_DATE). The committed string comes back unchanged from
  canonical JSON (`/openehr/v1`), `to_rm` and the FHIR facade. The same holds for
  `EVENT_CONTEXT.start_time` and the event times of a history (#109).

### Changed
- The normalized value a DV_DATE_TIME or DV_DATE is ordered and compared by
  (`datetime_value`, `date_value`, used by SQL and the AQL engine) is the
  earliest instant or day the value covers, and a value without a UTC offset is
  read as UTC. This is the instant the openehr gem orders the value by. Before,
  an offset-less value was read in the app's `Time.zone`, and a value to the
  hour lost its hour. It is an internal value; what the API returns is the
  committed string. Values with an offset, which is everything a scaffolded
  model writes, are normalized as before. Rows stored before this release keep
  their normalized value until they are committed again (#109).

semver: patch. A bug fix. The one behaviour change is the normalized instant of
an offset-less date-time when `Time.zone` is not UTC. That instant is internal,
but it is what AQL compares by, and the change is what R-20261127-31 decided
(match the openehr gem). No migration, no dependency change.

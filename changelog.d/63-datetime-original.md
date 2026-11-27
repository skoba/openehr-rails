### Fixed
- A `DV_DATE_TIME` value read back from the RM graph keeps the ISO 8601 string it
  was committed with: partial precision (`2026-03-01`, `2026-03-01T10:00`) and the
  UTC offset (`+09:00`) are no longer lost. Canonical JSON (`to_canonical_hash`,
  the REST GET) and `Rm::Composition#to_rm` return it unchanged. Until now a
  date-only `2026-03-01` came back as the previous day's instant
  (`2026-02-28T15:00:00Z` with `Time.zone` at +09:00) (#63).

### Changed
- `Rm::Composition#to_rm` and `Rm::RmObjectBuilder.new` accept
  `normalize_date_times:` (default `false`). AQL still evaluates `DV_DATE_TIME`
  values as the normalized UTC instant, because openehr's
  `DvDateTime#magnitude` (2.7.0 and earlier) applies a positive UTC offset with
  the wrong sign; AQL switches to the committed string once a fixed openehr is the
  lower bound (#63).

### Upgrade note
- No migration. The committed string is kept in `openehr_rm_data_values.text_value`
  of the `DV_DATE_TIME` row; `datetime_value` stays the normalized instant used
  for SQL and ordering. Rows written before this release have no copy of the
  original string and keep reading back as the UTC instant.

<!-- semver: minor. Read-back values change (the committed string instead of the
UTC instant), and to_rm / RmObjectBuilder gain a keyword argument. No column,
no migration, AQL results unchanged. -->

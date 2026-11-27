### Fixed
- The FHIR facade serves an Observation's date and time values in FHIR's forms,
  on the scaffold path and the runtime path, by the rule Condition follows (#104):
  - DV_DATE_TIME (`valueDateTime`, also in `component[]`): a typed column's
    time was served as `"2026-11-20 09:30:00 UTC"` and is now ISO 8601. A
    recorded string is served as recorded when it is a FHIR dateTime
    (`2026`, `2026-11`, `2026-11-27`, a full date-time with an offset). A
    time without seconds gets `:00`, and a time without an offset is read as
    UTC. A value to the hour, which FHIR has no form for, is served to the day.
    Condition now does the same for a value to the hour (#110).
  - DV_DATE is served as `valueDateTime` holding the date, because
    Observation.value[x] has no `date` in R5. Generated profiles type such a
    leaf `dateTime`, and `POST /fhir/Observation` reads it from `valueDateTime`
    (#110).
  - DV_TIME (`valueTime`) is `hh:mm:ss`. A typed column's time was served with
    a date. Seconds are zero-filled. A recorded offset is left out, because
    FHIR time cannot carry one; the clock reading is kept. A value to the hour
    is left out (#110).

semver: patch. Bug fixes: each output changed was not a valid FHIR value
before. The `valueDate` → `valueDateTime` key and the profile type for DV_DATE
leaves change shape, but `valueDate` is not allowed on Observation.

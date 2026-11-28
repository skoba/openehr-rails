### Fixed

- A scaffolded model no longer drops or alters a date/time value its column
  cannot hold (#122). A DV_DATE_TIME, DV_DATE or DV_TIME field kept in a
  `datetime`, `date` or `time` column refuses, with a validation error naming
  the value ("cannot hold 2026-11 at the precision it was given"):
  - for `datetime`: a year, a year-month, a date with no time, a value to the
    hour (Rails cast these to nil or midnight);
  - for `date`: a year or a year-month (cast to nil);
  - for `time`: a value to the hour (cast to `hh:00:00`);
  - any string the column cannot read (cast to nil).

  Values to the minute or second, with or without an offset, and `Date`/`Time`
  objects save as before. A field kept in a string column is not checked. The
  check is in the gem (`OpenehrRails::DateTimePrecision`, included by
  `Storable`), so generated models need no regeneration.

  **Upgrade note.** A save that used to succeed with the value silently gone
  (or set to midnight) now fails validation; a FHIR POST carrying such a value
  to a scaffolded model gets 422. Partial values are stored through the RM
  graph path (`/openehr/v1`, `CompositionCommitter`).

semver: minor. A bug fix, but a save or POST that succeeded before is now
refused, which host apps can see.

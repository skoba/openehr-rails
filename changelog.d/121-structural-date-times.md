### Fixed

- EVENT.time, HISTORY.origin and EVENT_CONTEXT.start_time come back as
  committed (#121). REST and FHIR (`effectiveDateTime` of a runtime record)
  returned them as full UTC instants: `2026-03-01` became
  `2026-03-01T00:00:00Z` and a `+09:00` offset became UTC. The committed
  string is kept in the row's existing `extra` JSON column; the instant
  columns stay for ordering and AQL comparison. No migration.
- REST `GET /v1/ehr/:ehr_id/composition/:uid` returns the composition's
  `context` (`start_time`, `setting`), which it left out. A scaffold record
  gets the context its `composed_at` gives it, when the configured category is
  event (`433`, the default); a persistent one gets no added context.
- No read makes up a date-time or a setting:
  - a scaffold record writes its save time (`composed_at`, in UTC) into
    `HISTORY.origin` and `EVENT.time`; AQL used to answer `EVENT.time` with
    the clock at query time;
  - a stored row without `EVENT.time` / `HISTORY.origin` (saved before this
    release) takes its context start time; a row with neither is left out of
    AQL with a warning instead of being given the clock;
  - a context without a setting reads as `OpenehrRails.default_setting`,
    `238` other care, instead of `other` / `other` (not an openehr code).

### Added

- `OpenehrRails.default_setting` (`['238', 'other care']`): the setting a
  scaffold record's context gets. Assigning a code outside the openehr setting
  group raises `ArgumentError`, so a wrong initializer fails at boot.
- `CompositionCommitter.commit(context_start_time:)` takes a String as a
  recorded value, kept as written (a `Time` is stored as before).

### Changed

- **Upgrade note.** A commit (`/v1` POST/PUT, or `CompositionCommitter.commit`)
  without `HISTORY.origin` or `EVENT.time`, or with a context lacking
  `start_time` or `setting`, is refused: `OpenehrRails::Rm::MissingRequiredAttributes`,
  answered by `/v1` with 422 naming the missing paths. Such commits used to
  succeed and read back with made-up values. A logical delete re-commits the
  stored head and is not checked. Rows stored before this release keep their
  instants; the committed strings were not kept and cannot be recovered.

semver: minor. Bug fixes, but REST responses gain `context`, date-times read
back in their committed form, and commits that used to succeed are refused.

### Added
- openEHR REST `GET /v1/ehr?subject_id=...&subject_namespace=...` (ITS-REST EHR
  API, "Get EHR by subject id"): returns the EHR whose `EHR_STATUS.subject`
  matches both parameters, in the same shape as `GET /v1/ehr/:ehr_id`, or 404
  when none does. Two answers are this implementation's own, because the
  specification does not cover them: several EHRs for one subject return 409
  with `{ "error": ..., "ehr_ids": [...] }` (oldest first) instead of one picked
  silently, and a missing or blank parameter returns 400 with `{ "error": ... }`.
  Access scope is `:rest_api`, as for the other REST endpoints (#95).

<!-- semver: minor. A new REST endpoint (public API addition); existing routes
are unchanged. -->

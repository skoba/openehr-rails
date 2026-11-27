### Fixed
- openEHR REST `POST /v1/ehr` no longer creates a second EHR for a subject that
  already has one. When an EHR already has the same `EHR_STATUS.subject`
  id, namespace pair, it returns 409 with
  `{ "error": ..., "ehr_ids": [...] }` (the existing EHRs, oldest first, as in
  the 409 of `GET /v1/ehr?subject_id=...`), as the ITS-REST EHR API "Create
  EHR" requires. Before, it answered 201 (#99).

### Changed
- `PUT /v1/ehr/:ehr_id` refuses a second EHR for a subject in the same way
  (409 with `ehr_ids`). The specification's 409 for this operation covers only
  an `ehr_id` already in use; extending it to the subject is this
  implementation's own handling, so the outcome does not depend on which
  endpoint was used. The `ehr_id`-in-use 409 is unchanged (`{ "error": ... }`
  only) (#99).

### Upgrade notes
- A client that relied on creating several EHRs for one subject (both
  `subject_id` and `subject_namespace` given) now gets 409 for the second one.
  EHRs without a full subject pair (anonymous) are not compared and can still
  be created repeatedly. Duplicates that already exist are not touched;
  `GET /v1/ehr?subject_id=...` reports them with 409 (#99).

### Known limitations
- No database unique index backs the subject check (it would need a migration
  in every host app, and would fail where duplicates already exist), so two
  concurrent create requests for the same subject can both succeed (#99).

<!-- semver: minor. A bug fix, but the default behavior of two public
endpoints changes (requests that answered 201 now answer 409), so it is
released as a minor with an upgrade note. -->

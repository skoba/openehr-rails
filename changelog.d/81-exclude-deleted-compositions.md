### Changed
- **Upgrade note.** AQL no longer returns logically deleted compositions by default.
  The default `composition_scope` of `OpenehrRails::Aql::Executor.execute` (and
  `Aql::DatasetAdapter.build`) is now `Rm::Composition.latest.not_deleted`; pass
  `composition_scope: OpenehrRails::Rm::Composition.latest` to include them again.
  The engine's EHR screen (`/openehr/ehrs`) leaves them out of its counts and
  timeline as well. Only compositions deleted through the REST
  `DELETE /v1/ehr/:ehr_id/composition/:uid` are affected; a scaffolded record's
  `destroy` still purges its graph (#81, anlage upstream 28).

### Added
- `Rm::Composition.not_deleted` scope, and `Rm::CompositionCommitter.delete(uid:, ehr:)`,
  which the REST DELETE now uses (#81).

### Fixed
- A logical delete's Contribution is recorded as `deleted` (523), not `amendment`
  (250), and its version is created with lifecycle 523 in one step (#81).

<!-- semver: minor (0.x). The default AQL result changes for stores that hold
     REST-deleted compositions; no schema change. -->

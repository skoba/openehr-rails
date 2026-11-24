<!-- semver: minor. The dependency floor rises (openehr ~> 2.5). -->

### Changed
- **Upgrade note.** Requires `openehr` `~> 2.5` (was `~> 2.3, >= 2.3.1`). A host app
  locked to openehr 2.4.x must update it together with this gem.
- `OpenehrRails::Opt::Parser` no longer reads OPT `term_bindings` itself: openehr
  2.5.0 does (openehr-ruby#31), and the interim bypass is removed (#59).

### Fixed
- An OPT embedding the same archetype more than once no longer yields each term
  binding once per occurrence: `code_bindings` holds one entry per binding, so the
  FHIR `code.coding` slices are not duplicated. Two behaviours follow upstream and
  differ from the removed bypass: a binding item without a `terminology_id` is no
  longer completed from the `term_bindings` element's `terminology` attribute, and
  when roots of the same archetype carry *different* bindings the last root wins
  instead of their union (#59).

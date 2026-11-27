### Added
- The FHIR facade (`/openehr/fhir`) serves records of templates registered
  at runtime: compositions in the RM graph that no scaffolded model owns
  (committed through `/openehr/v1` or `Rm::CompositionCommitter`). Search
  (`code`, `subject`), read by id, the CapabilityStatement and
  StructureDefinition answer for them through the same endpoints. Values
  are read from the RM graph with the same path walk Storable uses (#101).
- `OpenehrRails::Fhir.template_source`: a callable returning one
  `{ template_id:, opt: }` per template id, for a host app that keeps its
  templates outside the gem's `OpenehrTemplate` registry (the default):

  ```ruby
  # config/initializers/openehr.rb
  Rails.application.config.to_prepare do
    OpenehrRails::Fhir.template_source = lambda do
      Template.where(status: 'active').map { |t| { template_id: t.template_id, opt: t.source_xml } }
    end
  end
  ```

  A template id returned twice raises `OpenehrRails::Fhir::TemplateSourceError`
  (answered 500) instead of one being picked silently (#101).

### Changed
- `GET /fhir/StructureDefinition/:id` also finds a generated profile when the
  host has profile files under `app/fhir/profiles` for other templates (#101).
- The CapabilityStatement lists each archetype once in `supportedProfile`
  even when several templates use it (#101).

### Upgrade notes
- A host whose `OpenehrTemplate` registry holds a template with no scaffolded
  model, and whose RM graph holds records of it (e.g. committed through
  `/openehr/v1`), now sees those records in FHIR search results. A template
  that has a scaffolded model is still served by the model only (#101).

### Known limitations
- Runtime records are read with the fields of the template the source
  returns now. A record written with an older version of the template shows
  only the fields that version shares with the current one (#101).
- A composition whose uid is not a UUID has no valid FHIR id
  (`c<uuid hex>-<entry index>`) and is not served (#101).
- Only Observation entries are served from runtime templates; EVALUATION and
  other entry types follow with the Condition fix (#101).
- Where a template repeats an archetype root, values are read from its first
  instance, as `Storable.from_rm_composition` does (#101).

<!-- semver: minor. Public API addition (OpenehrRails::Fhir.template_source,
records of runtime templates on existing endpoints); the scaffold path's
output is unchanged (serializer_spec unchanged, regression pins). -->

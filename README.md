English | [日本語](README.ja.md)

[![CI](https://github.com/skoba/openehr-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/skoba/openehr-rails/actions/workflows/ci.yml)

# Synopsis

openehr-rails turns an openEHR Operational Template (`.opt`) into a
working Rails resource in one command — model, migration, CRUD UI,
i18n locale, and HL7 FHIR R5 profiles. What sets it apart: usability
and openEHR conformance usually trade off against each other, but here
you get both. The generated model behaves like any ordinary
ActiveRecord model (typed columns, familiar forms and queries), while
every save also persists a fully conformant openEHR RM Composition —
canonical JSON plus a versioned, audit-trailed node graph — with no
hand-written mapping code. HL7 FHIR R5 support is derived automatically
from the same RM type mapping rather than hand-coded per resource, and
AQL (openEHR's query language) works identically from a Ruby model API
(`Model.aql`), a REST endpoint, and a browser console.

## Requirements

* Current version supports Rails 7.0+ and Rails 8.x
* Requires Ruby 3.3 or later (tested with Ruby 3.4)
* Developed with CRuby 3.4 on Linux
* Previous versions supported older Ruby/Rails versions (see git history)

## Usage

Generate a complete Rails resource (model, migration, controller,
views, routes, i18n locale, request spec) from an openEHR Operational
Template (.opt):

```sh
# one-time setup: template registry model + migration + initializer
bin/rails generate openehr:install
bin/rails db:migrate

# scaffold from an OPT file
bin/rails generate openehr:scaffold path/to/your_template.opt
bin/rails db:migrate
bin/rails db:seed   # registers the template in the openehr_templates table
```

The generated model keeps typed columns for Rails forms and queries,
and **persists every record as a canonical openEHR RM Composition** —
first as a **typed node graph** in `openehr_rm_*` tables (if the
install migrations were run), and also as a JSON document in the
`rm_composition` column for backward compatibility and export.

The `FIELD_MAP` constant on the model links each column to its openEHR
RM path and data value type. `Model.find_by_path(rm_path, value)` 
resolves RM paths to columns (`OpenehrRails::AqlQueryable`); if a 
path is not in FIELD_MAP, the search falls back to the RM graph (when 
available), allowing arbitrary archetype elements to be queried 
(`OpenehrRails::Rm` layer).

The scaffolded form has no input for the event time, so a record writes its
save time (`composed_at`) into `HISTORY.origin` and `EVENT.time`, and into
the context's `start_time`. The context's setting is
`OpenehrRails.default_setting` (`238` other care unless the initializer sets
another openehr setting code; a code outside that group raises at boot). A
composition committed through the openEHR REST API (`/openehr/v1`) must carry
`HISTORY.origin` and `EVENT.time`, and, when it has a context, its
`start_time` and `setting`; one without them is refused with 422 naming the
missing paths. REST and FHIR return these date-times and the context as
committed, partial values and offsets included; AQL `SELECT` returns the
normalized instant (earliest instant, UTC).

Known limitations of the generated date and time columns:

* A value the column would drop or alter is refused with a validation error
  naming it: in a `datetime` column a year, a year-month or a value to the
  hour; in a `date` column a year or a year-month; in a `time` column a value
  to the hour.
* A date with no time (`2026-11-05`) in a `datetime` column is saved as
  midnight: a time that was not recorded is added. To keep the recorded
  precision, commit through the runtime path (`/openehr/v1`).

Options:

* `--namespace=ehr` namespaces controller, views and routes.
* `--fhir` also writes HL7 FHIR R5 StructureDefinition profiles (one
  per OPT entry) to `app/fhir/profiles/`. They can also be generated
  standalone with `bin/rails generate openehr:fhir_profile <opt>`.

### Template admin UI

`openehr:install` mounts an admin engine at `/openehr`. It lists the
registered templates and accepts OPT files via drag & drop upload;
the **Generate UI** button runs the scaffold generator inside the
running app (generates files, migrates, reloads routes), so the new
resource is usable immediately without restarting the server.

Runtime scaffolding writes files into the application, so it is
enabled in the development environment only. Override with:

```ruby
# config/initializers/openehr.rb
OpenehrRails.enable_runtime_scaffolding = true # or false
```

### Authentication

Everything the engine serves — the template admin UI, the AQL console,
the patient timeline, the openEHR REST API (`/openehr/v1`) and the FHIR
facade (`/openehr/fhir`) — handles clinical data, so outside the
`development` and `test` environments the engine is **closed by
default**: every request gets `403 Forbidden` until you configure an
authentication hook.

The hook runs as a `before_action` inside the engine controller handling
the request (`instance_exec`'d, so it can use `request`, `render`,
`redirect_to`, and any helper your app mixes into `ActionController::Base`).
Deny by rendering or redirecting — a hook that raises would be caught
and reported as a misleading error by some engine controllers'
`rescue_from StandardError`.

```ruby
# config/initializers/openehr.rb

# Devise:
OpenehrRails.authenticate_with = -> { authenticate_user! }

# Bearer token:
OpenehrRails.authenticate_with = lambda do
  authenticate_or_request_with_http_token do |token, _options|
    ActiveSupport::SecurityUtils.secure_compare(
      token, Rails.application.credentials.openehr_api_token.to_s
    )
  end
end
```

To use a different mechanism per surface, branch on `openehr_access_scope`
(`:admin` — template UI / AQL console / timeline, `:rest_api` — `/v1`,
`:fhir` — the FHIR facade):

```ruby
OpenehrRails.authenticate_with = lambda do
  case openehr_access_scope
  when :admin then authenticate_user!
  else authenticate_or_request_with_http_token { |t, _| valid_api_token?(t) }
  end
end
```

To intentionally run without authentication (e.g. behind a reverse
proxy that already authenticates, or a network-isolated internal app):

```ruby
OpenehrRails.allow_unauthenticated_access = true
```

Note: the JSON API controllers (`/v1`, `/fhir`) skip CSRF protection, so
prefer token authentication over session cookies for those.

### HL7 FHIR R5 facade

The engine also serves a FHIR R5 API under `<mount>/fhir`
(`/openehr/fhir` by default), backed by the scaffolded models:

* `GET /openehr/fhir/metadata` — CapabilityStatement listing every
  registered archetype profile
* `GET /openehr/fhir/StructureDefinition/:id` — generated profiles
* `GET /openehr/fhir/Observation?code=<archetype_id>&subject=<ref>` —
  searchset Bundle
* `GET /openehr/fhir/Observation/:id` — read
* `GET /openehr/fhir/Condition?category=<archetype_id>&subject=<ref>` and
  `GET /openehr/fhir/Condition/:id` — entries mapped to Condition
  (`openEHR-EHR-EVALUATION.problem_diagnosis.v1`), read and search only. The
  archetype coding sits on `Condition.category` (`Condition.code` is the
  diagnosis), so that is the parameter that narrows to it
* `POST /openehr/fhir/Observation` — create; the FHIR resource is
  converted through the model's FIELD_MAP and stored canonically as an
  openEHR RM Composition (`rm_composition` column). Errors are
  returned as OperationOutcome.

Mapping is derived automatically from openEHR RM types
(OBSERVATION→Observation, DV_QUANTITY→Quantity,
DV_CODED_TEXT→CodeableConcept, ...; see
`OpenehrRails::Fhir::TypeMap`). An entry is served as the resource its
profile describes: Observation entries as Observation, entries with a row in
`TypeMap::ENTRY_ELEMENT_MAPS` as that resource (today problem_diagnosis →
Condition), and other entries (INSTRUCTION, ACTION, ...) not at all.

Date and time values of an Observation follow the dateTime rule given for
Condition below. A DV_DATE is served as `valueDateTime` holding the date
(`Observation.value[x]` has no `date` in R5). A DV_TIME is served as
`valueTime`, `hh:mm:ss`; a recorded offset is left out (FHIR time cannot
carry one), and a value to the hour is not served.

#### Condition: values the facade sets, and known limitations

* `Condition.clinicalStatus` is required in FHIR R5, but the
  problem_diagnosis archetype records no clinical status. The facade sets it,
  and it is not a value from the record (system
  `http://terminology.hl7.org/CodeSystem/condition-clinical`):
  * `unknown` when the record has no date/time of resolution (at0030) — used
    as a null flavor: the record does not say;
  * `inactive` when it has one, served with `abatementDateTime`. at0030 means
    "resolution or remission" without saying which, so the facade does not
    claim `resolved`; `inactive` covers both and satisfies con-3.

  The generated profiles note this on `clinicalStatus` (no binding or fixed
  value is added).
* `verificationStatus` carries the archetype's local at-codes (e.g. `at0076`),
  which do not satisfy R5's required binding to `condition-ver-status`;
  translating them is a ConceptMap concern.
* at0003 (date/time clinically recognised) → `recordedDate` is an
  approximation; the profiles say so in `ElementDefinition.comment`.
* Date/time leaves (`onsetDateTime`, `recordedDate`, `abatementDateTime`) are
  served as recorded when they are valid FHIR dateTimes. A value with a time
  but no offset is read as UTC (as `Observation.effectiveDateTime` is), and
  missing seconds are filled in. A value to the hour, which FHIR has no form
  for, is served to the day.

#### Templates registered at runtime

Records that no scaffolded model owns — compositions committed into the
RM graph through the openEHR REST API (`/openehr/v1`) or
`OpenehrRails::Rm::CompositionCommitter` — are served through the same
endpoints, read straight from the RM graph. Their templates come from the
gem's `OpenehrTemplate` registry by default. A host app that keeps its
templates elsewhere hands them over with one callable, returning one
`{ template_id:, opt: }` (the OPT XML) per template id:

```ruby
# config/initializers/openehr.rb
Rails.application.config.to_prepare do
  OpenehrRails::Fhir.template_source = lambda do
    Template.where(status: 'active').map { |t| { template_id: t.template_id, opt: t.source_xml } }
  end
end
```

* Return the version current records should be read with; a template id
  returned twice raises `OpenehrRails::Fhir::TemplateSourceError` (500).
* A template that has a scaffolded model is served by the model only.
* Runtime records have ids `c<composition uuid hex>-<entry index>`; a
  composition whose uid is not a UUID is not served. `POST` to an archetype
  only a runtime template has answers 422 (there is no model to create
  into).
* Coded values of runtime records carry the record's own text as `display`
  and its terminology as `system`.

### Starting a new app from scratch

[`templates/openehr_template.rb`](templates/openehr_template.rb) is a
Rails application template that wires up a brand new app with
openehr-rails (`openehr:install`, migrated) in one command:

```sh
rails new myehr -m https://raw.githubusercontent.com/skoba/openehr-rails/master/templates/openehr_template.rb
```

Set `OPENEHR_SAMPLES=1` to also scaffold the 3 sample templates used by
this repo's own demo (BMI, problem list, blood pressure), fetched over
HTTP via `OpenehrRails::Opt::RemoteFetcher`. See the file's header
comment for all options.

[`script/build_starter.sh`](script/build_starter.sh) wraps the same
template to produce a standalone repo (with its own README and CI
workflow) suitable for pushing to GitHub as a
[template repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository).

### Demo app (OPT → Rails app)

`script/build_demo.sh` builds a demo Rails app from scratch with this gem:
it creates `demo/`, scaffolds three templates (BMI, problem list, blood
pressure) with FHIR profiles, and loads the sample data
(`demo_assets/demo_seed.rb`), in one run.

```sh
bash script/build_demo.sh            # FORCE=1 rebuilds an existing demo/
cd demo && bin/rails server          # http://localhost:3000
```

For the steps in detail, what is generated, the admin UI and how to check
the FHIR R5 facade, see the walkthrough in
[doc/DEMO.md](doc/DEMO.md) (Japanese: [doc/DEMO_ja.md](doc/DEMO_ja.md)). `demo/` can be rebuilt at
any time, so it is not tracked in git.

## License
This product is under Apache 2.0 license

 Copyright 2012-2026 Shinji Kobayashi, openEHR.jp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
    http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
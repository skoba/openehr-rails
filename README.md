{<img src="https://travis-ci.org/skoba/openehr-ruby.png?branch=master" alt="Build Status" />}[https://travis-ci.org/skoba/openehr-ruby]

# Synopsys

This is a support library for openEHR on Rails implementation and
still working exeperimental codes.

## Requirements

* Current version supports Rails 7.0+ and Rails 8.x
* Requires Ruby 3.0 or later (tested with Ruby 3.4)
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

### HL7 FHIR R5 facade

The engine also serves a FHIR R5 API under `<mount>/fhir`
(`/openehr/fhir` by default), backed by the scaffolded models:

* `GET /openehr/fhir/metadata` — CapabilityStatement listing every
  registered archetype profile
* `GET /openehr/fhir/StructureDefinition/:id` — generated profiles
* `GET /openehr/fhir/Observation?code=<archetype_id>&subject=<ref>` —
  searchset Bundle
* `GET /openehr/fhir/Observation/:id` — read
* `POST /openehr/fhir/Observation` — create; the FHIR resource is
  converted through the model's FIELD_MAP and stored canonically as an
  openEHR RM Composition (`rm_composition` column). Errors are
  returned as OperationOutcome.

Mapping is derived automatically from openEHR RM types
(OBSERVATION→Observation, DV_QUANTITY→Quantity,
DV_CODED_TEXT→CodeableConcept, ...; see
`OpenehrRails::Fhir::TypeMap`).

### Legacy generators

The ADL-based generators (`openehr:model`, `openehr:controller`,
`openehr:migration`, `openehr:template`, ...) predate the OPT
scaffold and are deprecated; they are kept for reference only.

## License
This product is under Apache 2.0 license

 Copyright [2012-2020] Shinji Kobayashi, openEHR.jp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
    http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
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
and additionally persists every record as a canonical openEHR RM
Composition JSON document in the `rm_composition` column on save
(see `OpenehrRails::Storable`). The `FIELD_MAP` constant on the model
links each column to its openEHR RM path and data value type, and
`Model.find_by_path(rm_path, value)` resolves RM paths to columns
(`OpenehrRails::AqlQueryable`).

Options:

* `--namespace=ehr` namespaces controller, views and routes.

### Legacy generators

The ADL-based generators (`openehr:model`, `openehr:controller`,
`openehr:migration`, `openehr:template`, ...) predate the OPT
scaffold and are deprecated; they are kept for reference only.

### Roadmap

* HL7 FHIR R5 profile (StructureDefinition) generation from OPT
* FHIR REST API facade storing data as openEHR RM compositions

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
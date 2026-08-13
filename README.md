[![CI](https://github.com/skoba/openehr-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/skoba/openehr-rails/actions/workflows/ci.yml)

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
* `POST /openehr/fhir/Observation` — create; the FHIR resource is
  converted through the model's FIELD_MAP and stored canonically as an
  openEHR RM Composition (`rm_composition` column). Errors are
  returned as OperationOutcome.

Mapping is derived automatically from openEHR RM types
(OBSERVATION→Observation, DV_QUANTITY→Quantity,
DV_CODED_TEXT→CodeableConcept, ...; see
`OpenehrRails::Fhir::TypeMap`).

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

### デモ環境（OPT → Rails アプリ）

`script/build_demo.sh` は、この gem を使って **OPT から Rails アプリを生成し
動かすデモ**をゼロから再現構築します（`demo/` を新規作成 → BMI / 問題リストの
2 テンプレートを scaffold → サンプルデータ投入まで一括実行）。

```sh
bash script/build_demo.sh
cd demo && bin/rails server   # http://localhost:3000
```

手順の詳細・生成物の解説・管理 UI・FHIR R5 facade の確認方法は
日本語マニュアル [doc/DEMO_ja.md](doc/DEMO_ja.md) を参照してください。
生成される `demo/` は再現可能なため git では追跡しません。

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
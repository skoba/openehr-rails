# Demo: a Rails app from openEHR templates (walkthrough)

Japanese version: [DEMO_ja.md](DEMO_ja.md).

This walkthrough uses the `openehr-rails` gem to **generate Rails resources
(model, migration, controller, views, i18n, FHIR profiles) from openEHR
Operational Templates (.opt) and run them as a working app**.

It scaffolds three templates of different shapes:

| Template | openEHR entry type | Main data types | Generated resource |
|---|---|---|---|
| BMI calculation (`bmi_calculation`) | OBSERVATION | DV_QUANTITY (value + unit) / DV_TEXT | `/bmi_calculations` |
| Problem list (`ProblemList`) | EVALUATION | DV_CODED_TEXT / DV_DATE_TIME | `/problemlists` |
| Blood pressure (`patient_blood_pressure.v1`) | OBSERVATION | DV_QUANTITY (pulse + systolic/diastolic) / several archetypes | `/patient_blood_pressures` |

A numeric template, a coded-text-and-date template and a vital-signs template
that bundles several archetypes run side by side in one app, with CRUD
screens, the admin UI and the HL7 FHIR R5 facade.

> The blood pressure template bundles two OBSERVATION archetypes,
> `heart_rate-pulse` and `blood_pressure`, in one OPT. The hyphen in
> `heart_rate-pulse` is not valid in an identifier, so the column and
> attribute names become `heart_rate_pulse`.

---

## 1. What the demo shows

- One `.opt` file is enough to generate a standard Rails CRUD resource.
- Generated models keep **typed columns** (for forms and search) and, on
  save, persist an **openEHR RM Composition** both as JSON
  (`rm_composition`) and as a typed node graph in the `openehr_rm_*` tables.
- `FIELD_MAP` ties each column to its openEHR RM path and data type.
- The admin UI (`/openehr`) uploads OPTs and scaffolds them at runtime.
- The same data can be read (and Observations written) as **HL7 FHIR R5**
  resources.

---

## 2. Prerequisites

- Ruby 3.3 or later (checked with 4.0.10)
- Bundler and Rails 8 (`gem install rails`; checked with 8.1.4.1)
- SQLite3
- A checkout of `openehr-rails` (this repository)

```sh
ruby -v
bundle -v
rails -v
```

---

## 3. Quick start (the build script)

From the repository root, the script builds a Rails app in `demo/` from
scratch, scaffolds the three templates, runs the migrations and loads the
sample data, in one run.

```sh
cd /path/to/openehr-rails
bash script/build_demo.sh        # asks before rebuilding an existing demo/
# rebuild without asking:
FORCE=1 bash script/build_demo.sh

cd demo
bin/rails server
```

Open these in a browser (default port 3000):

| URL | What it is |
|---|---|
| <http://localhost:3000/bmi_calculations> | BMI CRUD screens |
| <http://localhost:3000/problemlists> | Problem list CRUD screens |
| <http://localhost:3000/patient_blood_pressures> | Blood pressure CRUD screens |
| <http://localhost:3000/openehr> | Admin UI (templates, runtime scaffolding) |
| <http://localhost:3000/openehr/query> | AQL query console |
| <http://localhost:3000/openehr/ehrs> | Patient timeline |
| <http://localhost:3000/openehr/fhir/metadata> | FHIR CapabilityStatement |

`/` is Rails' default welcome page (the demo defines no root route).

`demo/` can be rebuilt at any time, so it is not tracked in git (it is in
`.gitignore`). Delete it and run the script again to get the same result.

### 3.1 With Docker (no local Ruby or Rails)

With only Docker installed, the same demo runs in a container:

```sh
cd /path/to/openehr-rails
docker compose -f docker/docker-compose.yml up --build
```

Open <http://localhost:3000/openehr>. SQLite data is kept in the named
volume `demo-storage`, so it survives re-creating the container
(`docker compose -f docker/docker-compose.yml down -v` removes it). The
container runs in development (`RAILS_ENV=development`), so the admin UI's
runtime scaffolding ("Generate UI" and URL import) works as is.

---

## 4. Step by step (what the script does)

### 4.1 Create the Rails app and wire the gem

```sh
rails new demo --database=sqlite3 --skip-test --skip-jbuilder \
  --skip-action-mailbox --skip-action-cable --skip-kamal --skip-ci
cd demo
echo 'gem "openehr-rails", path: ".."' >> Gemfile   # local path
bundle install
```

(The script also adds `rspec-rails` and runs `rspec:install`, because
`openehr:scaffold` writes request specs.)

### 4.2 One-time setup (openehr:install)

Adds the template registry model, the RM persistence tables and the admin
engine (`/openehr`).

```sh
bin/rails generate openehr:install
bin/rails db:migrate
```

### 4.3 Scaffold the BMI template (with `--fhir`)

```sh
bin/rails generate openehr:scaffold ../demo_assets/templates/bmi_calculation.opt --fhir
bin/rails db:migrate
bin/rails db:seed     # registers the template in openehr_templates
```

Expected output (excerpt):

```
Generating scaffold for template: bmi_calculation
Model name: BmiCalculation
      create  app/templates/operational/bmi_calculation.opt
      append  db/seeds.rb
      create  app/models/bmi_calculation.rb
      create  db/migrate/XXXXXXXXXXXXXX_create_bmi_calculations.rb
      create  app/controllers/bmi_calculations_controller.rb
      create  app/views/bmi_calculations/{index,show,new,edit,_form}.html.erb
      create  config/locales/bmi_calculation.en.yml
       route  resources :bmi_calculations
      create  spec/requests/bmi_calculations_spec.rb
      create  app/fhir/profiles/openehr-bmi-calculation-observation-height-v2.json
      create  app/fhir/profiles/openehr-bmi-calculation-observation-body-weight-v2.json
      create  app/fhir/profiles/openehr-bmi-calculation-observation-body-mass-index-v2.json
```

Profile ids carry the template id, so the same archetype in two templates
gets two profiles.

### 4.4 Scaffold the problem list and blood pressure templates

```sh
bin/rails generate openehr:scaffold ../demo_assets/templates/problem_list.opt --fhir
bin/rails db:migrate
bin/rails db:seed

bin/rails generate openehr:scaffold ../demo_assets/templates/patient_blood_pressure.opt --fhir
bin/rails db:migrate
bin/rails db:seed
```

These generate `Problemlist` (`resources :problemlists`,
`app/fhir/profiles/openehr-problemlist-evaluation-problem-diagnosis-v1.json`)
and `PatientBloodPressure` (`resources :patient_blood_pressures`, one profile
per archetype).

### 4.5 Load the sample data

```sh
bin/rails runner ../demo_assets/demo_seed.rb
# => [demo_seed] BmiCalculation: 4 records
#    [demo_seed] Problemlist: 3 records
#    [demo_seed] PatientBloodPressure: 3 records
#    [demo_seed] Ehr: 3 records
```

---

## 5. What gets generated

### 5.1 Model (`app/models/bmi_calculation.rb`)

```ruby
class BmiCalculation < ApplicationRecord
  include OpenehrRails::Storable      # builds and persists the RM Composition on save
  include OpenehrRails::AqlQueryable  # search by RM path

  TEMPLATE_ID = 'bmi_calculation'
  ROOT_ARCHETYPE_ID = 'openEHR-EHR-COMPOSITION.report-result.v1'

  # Single source of truth linking columns to openEHR RM paths and types.
  FIELD_MAP = {
    'height' => { label: "身長", path: ".../items[at0004]/value",
                  rm_type: "DV_QUANTITY", column_type: :float, units: "cm", ... },
    'body_weight'     => { ..., rm_type: "DV_QUANTITY", units: "kg" },
    'body_mass_index' => { ..., rm_type: "DV_QUANTITY", units: "kg/m2" },
    'body_mass_index_at0013' => { label: "判定", rm_type: "DV_TEXT", column_type: :string },
  }.freeze

  validates :height, numericality: { ... }, allow_nil: true
  # ...
end
```

- `FIELD_MAP` is the single table linking typed columns to openEHR RM paths
  and data types. Labels come from the OPT's terminology (this template is
  authored in Japanese).
- `Model.find_by_path(rm_path, value)` searches by RM path (`AqlQueryable`).

### 5.2 Migration (typed columns plus RM storage columns)

```ruby
create_table :bmi_calculations do |t|
  t.float  :height
  t.string :height_units, default: 'cm'          # DV_QUANTITY: value + unit columns
  t.float  :body_weight
  t.string :body_weight_units, default: 'kg'
  t.float  :body_mass_index
  t.string :body_mass_index_units, default: 'kg/m2'
  t.string :body_mass_index_at0013               # DV_TEXT
  t.string :ehr_id
  t.datetime :composed_at
  t.json   :rm_composition                        # canonical RM Composition (JSON)
  t.string :template_id, null: false, default: 'bmi_calculation'
  t.string :uid
  t.timestamps
end
```

### 5.3 Forms: inputs by data type

`_form.html.erb` picks the input from the openEHR data type:

| openEHR type | Generated input |
|---|---|
| DV_QUANTITY | `number_field` (min/max/step, with a unit label), e.g. `身長 [____] cm` |
| DV_TEXT | `text_field` |
| DV_DATE_TIME | `datetime_field` (`datetime-local`) |
| DV_CODED_TEXT with a code list | `select`, e.g. Suspected / Confirmed (`at0074` / `at0076`) |

> Known limitation: a **DV_CODED_TEXT without a code list**, such as the
> problem name (`problem_diagnosis_problem_diagnosis_name`), is generated as a
> `select` with no options. Values can still be stored and shown
> (`demo_seed.rb` stores free text).

### 5.4 i18n locale (from the OPT's terminology)

```yaml
en:
  activerecord:
    models:
      bmi_calculation: Bmi calculation
    attributes:
      bmi_calculation:
        height: "身長"
        body_weight: "体重"
        body_mass_index: "Body mass index"
        body_mass_index_at0013: "判定"
```

### 5.5 Stored as openEHR (RM Composition)

On save, `FIELD_MAP` turns the record into one COMPOSITION, persisted in the
`rm_composition` column (JSON) and in the `openehr_rm_*` tables.

```sh
bin/rails runner 'r=BmiCalculation.first; puts r.rm_composition.keys.inspect'
# => ["_type", "archetype_node_id", "archetype_details", "content", "uid"]
```

---

## 6. CRUD screens

- <http://localhost:3000/bmi_calculations>: the four seed records
  (patient-001 twice, BMI 22.7 and 22.5; patient-002 19.2; patient-003 29.3).
  "New" creates a record from numbers; edit and delete work too.
- <http://localhost:3000/problemlists>: Hypertension, Type 2 diabetes
  mellitus, Suspected asthma. Diagnostic certainty is a Suspected / Confirmed
  drop-down.
- <http://localhost:3000/patient_blood_pressures>: three seed records
  (120/80, 148/92, 110/70; pulse 72, 88, 60). Pulse, systolic and diastolic are
  number fields with units (`/min`, `mm[Hg]`).

---

## 7. Admin UI (`/openehr`)

<http://localhost:3000/openehr> is the template management engine.

- Lists the registered templates (`bmi_calculation`, `ProblemList`,
  `patient_blood_pressure`), with a link to each scaffolded resource.
- Uploads OPT files by drag and drop.
- Imports an OPT from a URL (HTTP/HTTPS): enter it and press "Import" to
  fetch, validate, save to `app/templates/operational/` and register it, all
  from the browser. `rails g openehr:scaffold <URL>` and
  `rails g openehr:fhir_profile <URL>` take a URL the same way. Redirects,
  timeouts, the size limit and allowed schemes are handled by
  `OpenehrRails::Opt::RemoteFetcher`.
- "Generate UI" (shown for a template that has not been scaffolded yet) runs
  the scaffold generator **inside the running app**: files, migration, route
  reload. The new resource is usable without restarting the server.

> Runtime scaffolding writes files into the app, so it is enabled in
> development only by default. Switch it with
> `OpenehrRails.enable_runtime_scaffolding` in
> `config/initializers/openehr.rb`.

---

## 8. HL7 FHIR R5 facade

The engine serves a FHIR R5 API at `<mount>/fhir` (`/openehr/fhir` by
default). Each entry is served as the resource its profile describes:
OBSERVATION entries (BMI, blood pressure) as Observation, and the problem
list's problem_diagnosis entry as Condition.

### 8.1 CapabilityStatement

```sh
curl -s http://localhost:3000/openehr/fhir/metadata
# {"resourceType":"CapabilityStatement","status":"active",...,"fhirVersion":"5.0.0",...}
# rest[0].resource: Observation (5 profiles; read, search-type, create; code, subject)
#                   Condition   (1 profile;  read, search-type;         category, subject)
```

### 8.2 StructureDefinition (generated profiles)

```sh
curl -s http://localhost:3000/openehr/fhir/StructureDefinition/openehr-bmi-calculation-observation-height-v2
```

### 8.3 Search

```sh
curl -s http://localhost:3000/openehr/fhir/Observation
# {"resourceType":"Bundle","type":"searchset","total":18,
#  "entry":[{"resource":{"resourceType":"Observation",...,
#    "valueQuantity":{"value":170.0,"unit":"cm",...}}}, ...]}

# narrow to one archetype (code)
curl -s "http://localhost:3000/openehr/fhir/Observation?code=openEHR-EHR-OBSERVATION.height.v2"

# the problem list, as Condition (narrowed by category, where the archetype coding sits)
curl -s "http://localhost:3000/openehr/fhir/Condition?category=openEHR-EHR-EVALUATION.problem_diagnosis.v1"
```

`Condition.clinicalStatus` is required in FHIR R5 but not recorded by the
archetype; the facade sets it (`unknown` without a date/time of resolution,
`inactive` with one). See the README's FHIR section.

### 8.4 Create an Observation (FHIR in, openEHR stored)

POSTing a FHIR Observation stores it through the model's `FIELD_MAP` as an
openEHR RM Composition. A **single-leaf archetype** (height) is the clearest
example.

```sh
curl -s -X POST -H 'Content-Type: application/fhir+json' \
  http://localhost:3000/openehr/fhir/Observation \
  -d '{
    "resourceType":"Observation","status":"final",
    "code":{"coding":[{"system":"http://openehr.org/ckm/archetypes",
                       "code":"openEHR-EHR-OBSERVATION.height.v2"}]},
    "valueQuantity":{"value":172.5,"unit":"cm",
                     "system":"http://unitsofmeasure.org","code":"cm"}
  }'
# => HTTP 201 and the created Observation (JSON)

# check what was stored
bin/rails runner 'r=BmiCalculation.where.not(height: nil).last; \
  puts "height=#{r.height} rm=#{r.rm_composition.keys.inspect}"'
# => height=172.5 rm=["_type","archetype_node_id","archetype_details","content","uid"]
```

> Known limitation: a **multi-leaf archetype** such as `body_mass_index`
> needs FHIR `component[]`. POSTing it with `valueQuantity` alone stores a
> record with no values and answers 400 (OperationOutcome
> `undefined method '[]' for nil`). Use the single-leaf height
> (`height.v2`) in the demo. Only Observation can be created; a Condition's
> archetype code answers 422.

---

## 9. AQL query console and patient timeline

### 9.1 AQL query console (`/openehr/query`)

<http://localhost:3000/openehr/query> runs AQL (Archetype Query Language)
from the browser. Enter a query and press "Run query": it calls
`POST /openehr/v1/query/aql` (section 10) and shows the result as a table.
The pre-filled example (height values across all EHRs) runs as is. The
console also opens with a query from the URL
(`/openehr/query?q=...&query_parameters=...`), without running it.

Queries go through the same engine as `OpenehrRails::Aql.execute` and
`Model.aql`, so a query that cannot run is checked first and answered with a
readable error. LIKE (the AQL glob syntax `*` / `?`, not SQL's `%` / `_`),
MATCHES against a literal value list, standardPredicate / nodePredicate
inside CONTAINS (`[at0004]`), and mixing aggregate and plain columns
(implicit GROUP BY) run with openehr 2.3.0 or later. Not supported: MATCHES
with `TERMINOLOGY(...)` in the value list (it needs value-set expansion by an
external terminology server) and version-aware queries (VERSION,
LATEST_VERSION, ALL_VERSIONS, VERSIONED_COMPOSITION).

### 9.2 Patient timeline (`/openehr/ehrs`)

<http://localhost:3000/openehr/ehrs> lists each EHR (patient) with its
record count and last update. "Timeline" opens a patient
(`/openehr/ehrs/:ehr_id`) and shows **records of every template in time
order** (BMI, blood pressure and problem list on one timeline).

- Filter links by template at the top.
- Each record links to the scaffolded record it came from (e.g.
  `/bmi_calculations/2`).
- "canonical JSON" expands to show how the record is persisted as an openEHR
  RM Composition.
- An amended record shows its versions under "version history" (creation,
  amendment). `demo_seed.rb` makes one by `update!`-ing patient-001's first
  BMI record.

---

## 10. openEHR REST API (`/openehr/v1`)

QUERY, EHR and COMPOSITION resources.

```sh
# QUERY: run AQL, JSON result
curl -s -G http://localhost:3000/openehr/v1/query/aql \
  --data-urlencode 'q=SELECT o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude AS height FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2]'
# => {"q":"...","columns":[{"name":"height"}],"rows":[[170.0],[170.0],[158.0],[180.0]]}

# EHR: create (server-generated ehr_id)
curl -s -X POST http://localhost:3000/openehr/v1/ehr -d '{}' -H 'Content-Type: application/json'
# => 201 Created, Location: .../v1/ehr/<uuid>

# EHR: read, and find by subject
curl -s http://localhost:3000/openehr/v1/ehr/patient-001
curl -s "http://localhost:3000/openehr/v1/ehr?subject_id=<id>&subject_namespace=<namespace>"

# COMPOSITION: read (a bare uid or a versioned uid "uid::system::n")
curl -s http://localhost:3000/openehr/v1/ehr/patient-001/composition/<uid>
```

`PUT .../composition/:uid` answers `412 Precondition Failed` unless the
`If-Match: "<uid>::<system_id>::<version>"` header matches the current
version (the openEHR REST API's optimistic locking). `DELETE` is a logical
delete that adds a `Version::LIFECYCLE_DELETED` version, not a physical one.
Creating an EHR for a subject that already has one answers 409.

> Known limitation: creating or updating a COMPOSITION accepts only the shape
> of the canonical JSON Storable produces (no `language` / `encoding` /
> `subject` directly on the entries). Fully conformant openEHR JSON from a
> third party, with those on the entries, is refused with 400 (for example
> `unknown RM node type "CODE_PHRASE"`).

---

## 11. Three resources side by side

BMI (OBSERVATION, numbers), the problem list (EVALUATION, coded text and
date/time) and blood pressure (OBSERVATION, several archetypes) run in one
app. `bin/rails routes | grep -E 'bmi|problemlist|patient_blood_pressure|openehr'`
shows each resource, the admin engine and the FHIR routes.

---

## 12. Clean up and rebuild

```sh
# throw the demo app away and rebuild it (same result every time)
rm -rf demo
FORCE=1 bash script/build_demo.sh
```

---

## Appendix: files in this repository

```
script/build_demo.sh          the build script (automates this walkthrough)
demo_assets/
  templates/bmi_calculation.opt        OPT: BMI (OBSERVATION)
  templates/problem_list.opt           OPT: problem list (EVALUATION)
  templates/patient_blood_pressure.opt OPT: blood pressure (OBSERVATION, several archetypes)
  demo_seed.rb                         sample data
demo/                          the Rails app the script builds (not tracked)
doc/DEMO.md                   this walkthrough
doc/DEMO_ja.md                the same, in Japanese
```

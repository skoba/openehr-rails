# Fix: FieldExtractor terminology scope mis-resolution

- Status: draft, awaiting approval
- Target: `openehr-rails` (this repo). Does not touch `openehr-ruby` or Anlage.
- Queue position: #1 of the upstream sprint queue (bug / patch, no dependency on the others)
- Issue: [#25](https://github.com/skoba/openehr-rails/issues/25) (filed from the draft in
  §7 below). `#7` in the sprint queue was a local queue number, not a GitHub issue number —
  GitHub issue #7 in this repo is an unrelated, already-closed 2013 item ("generate
  index.json.jbuilder").

## 1. Bug summary

`OpenehrRails::Opt::FieldExtractor` resolves every ELEMENT's terminology label using the
**top-level ENTRY's** `archetype_id`, even when the ELEMENT actually lives inside an
**embedded archetype** (a `CLUSTER`, or another `OBSERVATION`, slotted in via
`C_ARCHETYPE_ROOT`). Each embedded archetype carries its own, separately-keyed terminology
(`component_terminologies[archetype_id]`), and re-numbers its at-codes starting from
`at0000`. Two silent failure modes result:

1. **Collision**: if the outer entry's terminology happens to define the same at-code
   (very common, since numbering restarts per archetype), `term_text` returns a real but
   *wrong* label from the wrong terminology — no error, no nil, just incorrect text.
2. **Missing**: if the outer entry's terminology has no term for that code (the common
   case), `term_text` returns `nil`, and `build_field` falls back to the raw at-code as the
   label (`field_extractor.rb:153`, `label: label || element.node_id`) — e.g. `"at0024"`
   shown to the user instead of the real term.

This affects every generated artifact that consumes `field[:label]` or
`field[:code_labels]`: the i18n locale file, generated form dropdowns, and (via
`field[:archetype_id]`, which has the same root cause) FHIR profile element coding.

## 2. Root cause, with citations

- `FieldExtractor#build_entry` (`lib/openehr_rails/opt/field_extractor.rb:104-120`) computes
  `archetype_id` once from the top-level entry root and stores it in `entry[:archetype_id]`.
- `FieldExtractor#collect_elements` (`field_extractor.rb:123-144`) walks the constraint tree
  depth-first, but only threads `node_path` through the recursion — never an archetype
  context. When it meets a non-`ELEMENT` child it just recurses
  (`collect_elements(child, node_path)`, line 140) regardless of whether that child is a
  plain nested constraint node or a `C_ARCHETYPE_ROOT` boundary into a different archetype.
- `FieldExtractor#build_field` (`field_extractor.rb:146-166`) always calls
  `term_text(entry[:archetype_id], element.node_id)` (line 149) — `entry[:archetype_id]` is
  the *outer* entry's id, fixed at `build_entry` time, never updated per element.
- `FieldExtractor#term_text` (`field_extractor.rb:258-267`) looks up
  `@template.component_terminologies[archetype_id]` — confirmed
  (openehr-ruby `lib/openehr/am/template.rb:11,78-85`) to be a `Hash` keyed by
  **archetype_id string**, with one entry per archetype encountered during parsing,
  populated once per `C_ARCHETYPE_ROOT` node (openehr-ruby
  `lib/openehr/parser/opt_parser.rb:119-123`, called from
  `lib/openehr/parser/xml_constraint_parsing.rb:18-29` on every `c_archetype_root` — both
  the template's own root and every nested embed). So the *correct* terminology for a
  nested `ELEMENT` genuinely lives in this hash under the embedded archetype's own id,
  separate from the outer entry's — `FieldExtractor` just never looks it up there.

### Why a naive `rm_type_name == 'C_ARCHETYPE_ROOT'` check won't work

`CArchetypeRoot#rm_type_name` (openehr-ruby
`lib/openehr/am/archetype/constraint_model.rb:488-506`, inherited accessor from `CObject`,
`constraint_model.rb:95-103`) is populated from the OPT's `<rm_type_name>` element, which
holds the RM type the embedded archetype constrains (e.g. `"CLUSTER"`, `"OBSERVATION"`) —
**never** the literal string `"C_ARCHETYPE_ROOT"`. That string only appears as the XML
`xsi:type` discriminator (openehr-ruby
`lib/openehr/parser/xml_constraint_parsing.rb:18`, confirmed against fixture
`spec/lib/openehr/opt_parser/eReferral.opt:277-278`:
`<children xsi:type="C_ARCHETYPE_ROOT" ...><rm_type_name>CLUSTER</rm_type_name>`), which
`FieldExtractor` never inspects (it only sees the already-built AM object graph, not raw
XML). The correct boundary check is the same duck-typing pattern `FieldExtractor` already
uses for top-level entries (`entry_root?`, `field_extractor.rb:99-102`:
`child.respond_to?(:archetype_id) && child.archetype_id`) — only `CArchetypeRoot` exposes a
non-nil `archetype_id`; plain `CComplexObject` nodes (ordinary nested constraint nodes) do
not (`constraint_model.rb:288-480` has no `archetype_id` reader). openehr-ruby's own
`archetype_validator.rb:102-113` (`archetype_roots`) uses the equivalent `is_a?(CArchetypeRoot)`
check as precedent for this exact kind of tree walk.

## 3. Fix approach

Thread the *effective owning archetype_id* through `collect_elements`, updating it whenever
the walk crosses a `C_ARCHETYPE_ROOT` boundary, instead of assuming it's constant for the
whole entry.

1. `collect_elements(node, path, archetype_id)` — add a third parameter, defaulted from the
   caller to `entry[:archetype_id]` at the initial call in `build_entry`
   (`field_extractor.rb:107`).
2. Inside the recursive walk (`field_extractor.rb:131-142`), before recursing into a
   non-`ELEMENT` child, check the same duck-typed boundary condition as `entry_root?`:
   `child.respond_to?(:archetype_id) && child.archetype_id`. If true, recurse with
   `child.archetype_id.value` as the new `archetype_id`; otherwise keep propagating the
   current one unchanged. (Do **not** gate this on `rm_type_name` — see §2.)
3. Change the collected tuples from `[element, path]` to `[element, path, archetype_id]` and
   update `build_entry` (`field_extractor.rb:116-118`) to unpack three values and pass the
   per-element `archetype_id` into `build_field`, instead of `build_field` reading
   `entry[:archetype_id]` internally.
4. In `build_field` (`field_extractor.rb:146-166`), use the passed-in per-element
   `archetype_id` for:
   - `term_text(archetype_id, element.node_id)` (label)
   - `field[:archetype_id]` itself (line 157) — see design decision below
   - `coded_text_constraints(constraint, archetype_id)` (line 163)
   - `symbol_constraints(constraint, archetype_id)` (line 164)
5. `entry[:archetype_id]` stays as-is and continues to mean "the entry's own archetype" for
   `concept_of`/`field_name`/FHIR entry-level coding (`build_entry`,
   `fhir/profile_generator.rb:37-40`) — those are unaffected; only the *field-level*
   archetype_id and terminology lookups change for elements nested inside an embed.

### Design decision: `field[:archetype_id]` should track the nearest enclosing archetype, not just term_text's internal lookup

The field hash's doc comment already says `archetype_id: id of the enclosing archetype root
(entry)` (`field_extractor.rb:14`) — ambiguous today because entry and "enclosing archetype
root" were always the same value. Once elements can live inside an embedded archetype, the
more correct reading is "nearest enclosing archetype root", i.e. the embedded CLUSTER's own
id for elements inside it. Recommend changing `field[:archetype_id]` itself (not just the
internal `term_text` call) to the per-element value. This is a two-birds fix:
`lib/openehr_rails/fhir/profile_generator.rb:104` builds each field's FHIR coding as
`"#{field[:archetype_id]}##{field[:node_id]}"` — currently wrong for embedded-archetype
elements for the same root-cause reason, and gets fixed for free.

Update the `archetype_id:` line in the class doc comment (`field_extractor.rb:14`) to say
"nearest enclosing archetype root (entry or embedded C_ARCHETYPE_ROOT)".

### Explicitly out of scope for this patch (record, don't fix here)

- **RM `path` correctness across an archetype-root boundary**: `collect_elements` currently
  builds `field[:path]` using only `node_id` predicates (e.g. `[at0025]`), the same way
  whether or not a `C_ARCHETYPE_ROOT` was crossed. Whether AQL/RM paths conventionally need
  an archetype-node predicate at that boundary (e.g.
  `.../items[openEHR-EHR-CLUSTER.imaging.v1]`) is a separate, path-correctness question,
  unrelated to label/terminology resolution. Flag as a follow-up investigation, not part of
  this bug/patch.
- **`term_text`'s language selection** (`field_extractor.rb:262-265`,
  `terminology.term_definitions.each_value { ... }`): this ignores the `lang` key of
  `term_definitions` (confirmed Hash-of-Array keyed by language code,
  `openehr-ruby/lib/openehr/am/archetype/ontology.rb:11,57-59,74-76`) and returns the first
  array containing a matching code, regardless of language. This is architecturally wrong
  but currently **inert**: `OpenEHR::Parser::OPTParser#term_definitions`
  (`openehr-ruby/lib/openehr/parser/opt_parser.rb:159-168`) only ever populates a single
  language key per template today, so `each_value` degenerates to "the only value." Also
  confirmed: `OpenehrRails.default_language` (`lib/openehr_rails.rb:56`) is **unused**
  anywhere in `opt/field_extractor.rb` or `opt/parser.rb` — it only affects RM Composition
  defaults in `rm/rm_object_builder.rb:43,80`, unrelated to this bug. Do not wire it in here.
  Record as a known latent issue for a future, separate patch (the correct primitive already
  exists upstream: `ArchetypeOntology#term_definition(lang:, code:)`,
  `openehr-ruby/lib/openehr/am/archetype/ontology.rb:74-76` — `term_text` should eventually
  call `component_terminologies[archetype_id].term_definition(lang: @template.original_language.code_string, code: code)`
  instead of scanning). Mixing this into the scope-fix patch would blur one bug/patch/PR
  into two unrelated concerns; keep them separate per the queue's "1 issue = 1 branch = 1
  PR" rule.

## 4. TDD plan

### Fixture

No `LabResultReport.opt` fixture currently exists in this repo or in `openehr-ruby`'s specs
(searched both). `openehr-ruby`'s own `spec/lib/openehr/opt_parser/eReferral.opt` already
contains a real, verified instance of exactly this shape — an `OBSERVATION.lab_test.v1`
entry whose tree embeds `OBSERVATION.imaging.v1` which itself embeds `CLUSTER.imaging.v1`
via nested `C_ARCHETYPE_ROOT`s, with a genuine at-code collision (`at0002`..`at0006` mean
"Any event"/"Tree"/etc. in the outer entry's terminology vs. "X-ray"/"CT scan"/etc. in the
embedded CLUSTER's — `eReferral.opt:11256-11258` vs. `:11637-11655`). Rather than pulling in
that ~11,000-line fixture wholesale, create a **new, reduced fixture** in this repo, modeled
on that same real structure but with content renamed to a lab-report scenario (matching the
sprint queue's "LabResultReport" framing) and trimmed to the minimum XML needed to parse:

- New file: `spec/templates/lab_result_report_reduced.opt` (do not touch any existing `.opt`
  fixture — this repo's convention, `CLAUDE.md`: "opt files must not be changed
  automatically"; add a new one).
- Outer entry: `openEHR-EHR-OBSERVATION.laboratory_test_result.v1`, one `ELEMENT` directly
  under it plus one `C_ARCHETYPE_ROOT` slot (`items`) embedding a `CLUSTER`. Give the outer
  entry's own terminology an `at0001` definition too (e.g. "検査状態" / "Test status") so the
  collision case is real, not hypothetical.
- Embedded archetype: `openEHR-EHR-CLUSTER.laboratory_test_analyte.v1`, with:
  - `ELEMENT node_id="at0001"` (DV_TEXT or DV_CODED_TEXT) whose term in the **CLUSTER's own**
    terminology is "分析結果" (test/analysis result) — this is the collision case: term_text
    must resolve to "分析結果", not to the outer entry's "検査状態" (or whatever placeholder
    wrong text results from looking it up in the wrong terminology).
  - `ELEMENT node_id="at0024"` (DV_TEXT) whose term in the CLUSTER's own terminology is
    "分析名" (test/analysis name), and which has **no corresponding at0024 term** in the
    outer entry's terminology — this is the missing case: today `term_text` returns `nil`
    and the field falls back to the literal string `"at0024"` as its label
    (`field_extractor.rb:153`); after the fix it must resolve to "分析名".

### Red

New spec file `spec/openehr_rails/opt/field_extractor_embedded_archetype_spec.rb`, following
the existing pattern in `field_extractor_spec.rb` (load via `OpenehrRails::Opt.parse`,
`described_class.new(template)`, assert on `extractor.fields`):

```ruby
describe 'with an entry containing an embedded archetype (C_ARCHETYPE_ROOT)' do
  # fixture: spec/templates/lab_result_report_reduced.opt
  it 'resolves the CLUSTER-side term instead of colliding with the outer entry (at0001)' do
    field = fields.find { |f| f[:node_id] == 'at0001' && f[:archetype_id] == 'openEHR-EHR-CLUSTER.laboratory_test_analyte.v1' }
    expect(field[:label]).to eq('分析結果')
  end

  it 'resolves a CLUSTER-only term that the outer entry has no definition for (at0024)' do
    field = fields.find { |f| f[:node_id] == 'at0024' }
    expect(field[:label]).to eq('分析名')
    expect(field[:label]).not_to eq('at0024') # no silent fallback to the at-code
  end

  it 'tags the field with the embedded archetype id, not the outer entry id' do
    field = fields.find { |f| f[:node_id] == 'at0024' }
    expect(field[:archetype_id]).to eq('openEHR-EHR-CLUSTER.laboratory_test_analyte.v1')
  end
end
```

Run against `master` (pre-fix) to confirm all three fail — expected failures: label for
`at0001` comes back as the outer entry's colliding term (or whatever value that collision
produces) instead of "分析結果"; label for `at0024` comes back as the literal `"at0024"`
fallback instead of "分析名"; `field[:archetype_id]` comes back as
`openEHR-EHR-OBSERVATION.laboratory_test_result.v1` instead of the CLUSTER id.

### Green

Implement §3 exactly — thread `archetype_id` through `collect_elements` → `build_entry` →
`build_field`, using the `child.respond_to?(:archetype_id) && child.archetype_id` boundary
check. Re-run the new spec plus the full existing `field_extractor*_spec.rb` family
(`field_extractor_spec.rb`, `_ordinal_spec.rb`, `_section_spec.rb`,
`_concept_slug_spec.rb`) and the full suite (`bundle exec rspec`) — none of those should
change behavior, since none of their fixtures (`bmi_calculation.opt`,
`bmi_calculation_without_uid.opt`, `sample_blood_pressure.opt`) contain a
`C_ARCHETYPE_ROOT` nested inside another entry (confirmed: their `C_ARCHETYPE_ROOT` nodes
sit directly under `/content` as sibling top-level entries, which `entry_root?` already
handles correctly and this fix doesn't touch).

### Refactor

- Confirm `collect_elements`'s three-tuple return doesn't leak awkwardly into
  `build_entry`'s `elements.map { |element, path| ... }` (`field_extractor.rb:116`) — update
  to `elements.map { |element, path, archetype_id| ... }`.
  variable name at the call site for clarity given `entry[:archetype_id]` (outer) and the
  per-element one now coexist.
- Update the class doc comment (`field_extractor.rb:14`, see §3 design decision) and add a
  short "why" comment at the boundary-check line in `collect_elements`, since the fact that
  `rm_type_name` can't be used for this check (§2) is exactly the kind of non-obvious
  landmine worth one line of comment to stop a future reader from re-introducing it.

## 5. Compatibility impact

- **Behavior change, not just a bug fix in the abstract**: any existing generated
  application whose OPT templates contain an embedded archetype with a *colliding* at-code
  (label currently silently wrong) or a *CLUSTER-only* at-code (label currently falls back
  to the raw at-code string) will see the generated i18n locale text, form dropdown option
  text, and FHIR profile element `coding.code` change on next `rails generate
  openehr:scaffold` re-run. This is the intended fix, but it's a visible output change for
  affected templates — call it out explicitly.
- **CHANGELOG**: add under `## [Unreleased]` → `### Fixed`, following the existing
  `### Fixed` entry style at `CHANGELOG.md:113-118`. Note both symptoms (collision +
  fallback-to-at-code) and that `field[:archetype_id]`/FHIR coding for embedded-archetype
  elements changes too.
- **Version**: propose a **patch** bump (`0.4.0` → `0.4.1`,
  `lib/openehr_rails/version.rb:4`) — this is a correctness fix with no public API surface
  change (no new required args, no removed methods); the `field[:archetype_id]` value change
  for a previously-mishandled case is a bug fix, not an intentional API contract change.
- No migration/generator-invocation changes needed; existing generated apps are unaffected
  until they regenerate a scaffold from a template containing an embedded archetype.

## 6. Reference material

If useful, the user (skoba) has offered to paste the relevant section of Anlage's WP2
extractor scope-resolution design (a similar problem solved in a sibling project) —
ask for it if the approach above needs a second design reference before implementation
starts. Not required to proceed; the openehr-ruby-side evidence in §2–3 is sufficient to
implement and test this fix standalone.

## 7. Issue draft (file this, or attach this doc, before opening the branch)

**Title**: `FieldExtractor resolves terminology labels using the wrong archetype scope for embedded archetypes (C_ARCHETYPE_ROOT)`

**Body**:

> `OpenehrRails::Opt::FieldExtractor#term_text` always looks up
> `component_terminologies[entry_archetype_id]`, where `entry_archetype_id` is the
> top-level ENTRY's archetype id, fixed once per entry. When an `ELEMENT` actually lives
> inside an embedded archetype (a `CLUSTER`, or nested `OBSERVATION`, slotted in via
> `C_ARCHETYPE_ROOT`), its terminology lives under the *embedded* archetype's own id in
> `component_terminologies`, which `FieldExtractor` never looks up.
>
> Two symptoms:
> 1. If the outer entry's terminology happens to define the same at-code (common, since
>    at-code numbering restarts per archetype), the label is silently wrong — a real term
>    from the wrong terminology, not an error.
> 2. If the outer entry's terminology has no such code, the label falls back to the raw
>    at-code string (e.g. `"at0024"`) instead of the real term.
>
> This affects generated i18n locale files, form dropdown option text
> (`field[:code_labels]`), and FHIR profile element coding
> (`field[:archetype_id]`, used in `fhir/profile_generator.rb`), for any OPT template that
> embeds an archetype via `C_ARCHETYPE_ROOT` nested inside another entry (common in lab
> report / composite observation templates). No existing spec fixture exercises this path
> today.
>
> See `docs/design/fix-terminology-scope-plan.md` for root-cause analysis and fix plan.

**Labels**: `bug`, `patch`

## 8. Stop point

This document covers explore + plan only, per the sprint instructions. Do not implement
until explicitly approved. Next steps after approval: hand off to Codex for implementation
against §3–4 above, then Claude Code review + full `bundle exec rspec` run before PR.

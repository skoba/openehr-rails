# Fix/Enhancement: FieldExtractor terminology binding extraction

- Status: draft, awaiting approval
- Target: `openehr-rails` (this repo). Reads (no writes) from `anlage` and
  `openehr-ruby` for reference implementation and upstream-gap evidence.
- Issue: [#30](https://github.com/skoba/openehr-rails/issues/30)
- Log: `docs/reports/binding-extraction-log.md`

## 1. Summary

`OpenehrRails::Opt::FieldExtractor` extracts only local `code_list` enumerations for
`DV_CODED_TEXT` fields (`field_extractor.rb:191-203`). It extracts neither of the two
external-terminology binding forms an OPT can carry:

1. **value_set_binding** — a `defining_code` constraint of type `C_CODE_REFERENCE`
   (external value-set reference, e.g. `terminology:http://id.who.int/icd/release/11/mms`
   for ICD-11), instead of a local `CODE_PHRASE` enumeration.
2. **code_binding** — an ontology-level `term_bindings` element mapping a local at-code
   to a fixed external-terminology code (e.g. SNOMED-CT, LOINC).

The same gap is the root cause of an existing bug: `ProfileGenerator`'s generated FHIR
`DV_CODED_TEXT` `binding` never carries `valueSet`, and for `C_CODE_REFERENCE`-typed
elements (empty local `code_list`) no `binding` is emitted at all
(`profile_generator.rb:125-128`).

This also blocks `skoba/anlage#17`'s FSH export feature, whose binding-mapping step
consumes `FieldExtractor#entries` and needs these two keys (arbitrated API shape,
`anlage/docs/design/fsh-plan.md` 裁定反映 2026-08-26, §5 below).

## 2. Root cause, with citations

- `FieldExtractor#coded_text_constraints` (`field_extractor.rb:191-203`) reads only
  `code_phrase.code_list`; it never checks whether `code_phrase` is a `CCodeReference`
  (which carries `reference_set_uri` instead) nor reads `term_bindings` at all.
- `FieldExtractor` walks only the OPT `content` tree (`content_roots`/`entry_roots`,
  `field_extractor.rb:65-97`); it never visits the ontology's `term_bindings` elements.
  `term_text` (`field_extractor.rb:264-273`) does read the same ontology's
  `term_definitions`, but not `term_bindings` — the AM object model simply has no
  `term_bindings` to read, per the next point.
- The parsed template's terminology objects
  (`@template.component_terminologies[archetype_id]`, instances of
  `OpenEHR::AM::Archetype::Terminology::ArchetypeTerminology <
  ArchetypeOntology`, openehr-ruby `lib/openehr/am/archetype/ontology.rb:6-8`) have an
  existing `term_bindings` accessor (`attr_accessor :term_bindings`, `ontology.rb:8`,
  with a `term_binding(terminology:, code:)` reader at `ontology.rb:70-72`) — but
  `OpenEHR::Parser::OPTParser` (which `OpenehrRails::Opt::Parser` subclasses,
  `lib/openehr_rails/opt/parser.rb:9`) never populates it: its terminology handling
  reads only `term_definitions` (`opt_parser.rb:151-169`, sole XPath `'term_definitions'`
  at `:162`). `skoba/openehr-ruby#31` ("OPTParser drops `term_bindings`") tracks this
  gap upstream and is **OPEN**.
- `defining_code` can constrain to either a local `CODE_PHRASE` (`code_list`) or an
  external `C_CODE_REFERENCE` (`reference_set_uri`). The latter is
  `OpenEHR::AM::OpenEHRProfile::DataTypes::Text::CCodeReference < CCodePhrase`
  (openehr-ruby `lib/openehr/am/openehr_profile/data_types/text.rb:51-52`,
  `attr_reader :reference_set_uri`), instantiated by `OPTParser` since **openehr
  v2.3.1** via `c_code_reference` (`lib/openehr/parser/xml_domain_type_parsing.rb:19-25`
  — reads the `referenceSetUri` XML element, nils an empty `code_list`).
  `skoba/openehr-ruby#30` ("OPTParser crashes with NoMethodError on `C_CODE_REFERENCE`
  children") tracked the pre-2.3.1 crash and is **CLOSED** (fixed in 2.3.1,
  `History.txt:114-124`). This repo's current lock is **openehr 2.3.0**
  (`Gemfile.lock:201`, gemspec `~> 2.3`, `openehr-rails.gemspec:31`) — i.e. **today,
  parsing any OPT containing `C_CODE_REFERENCE` crashes** on this repo's dependency
  floor. Raising the floor to `>= 2.3.1` is a prerequisite for the value_set_binding
  half of this fix, not just a nice-to-have.
- `ProfileGenerator#apply_value_constraints`'s `DV_CODED_TEXT` branch
  (`fhir/profile_generator.rb:125-128`):
  ```ruby
  when 'DV_CODED_TEXT'
    return if field[:code_list].nil? || field[:code_list].empty?

    element[:binding] = { strength: 'required' }
  ```
  returns *before* setting `binding` at all when `code_list` is empty — the case for
  every `C_CODE_REFERENCE`-constrained element. So today's bug is worse than "missing
  `valueSet`": such elements get no `binding` key whatsoever. Fixing this needs the
  early-return condition restructured, not a one-line addition.
- Consumers, all obtaining their template via `OpenehrRails::Opt.parse` /
  `OpenehrRails::Opt::Parser` (confirmed for every production call site):
  `lib/generators/openehr/scaffold/scaffold_generator.rb:27,32`,
  `lib/openehr_rails/template_registry.rb:59-60`,
  `lib/openehr_rails/fhir/profile_repository.rb:30`,
  `lib/generators/openehr/fhir_profile/fhir_profile_generator.rb:18`,
  `lib/openehr_rails/template_uploader.rb:56`. `ProfileRepository.find`
  (`profile_repository.rb:15-19`) serves cached `app/fhir/profiles/*.json` before
  regenerating — host apps must regenerate to pick up new bindings (compatibility
  note, §6).

## 3. Reference implementation: Anlage's `Opt::PathcardExtractor`

`app/lib/opt/pathcard_extractor.rb` (anlage, cross-repo read; **not** a class named
`TermBindingExtractor` — no such class exists in anlage):

- `bindings_for(element, archetype_id)` (`:243-257`) emits a `value_set_binding` when
  the element's `defining_code` constraint `is_a?(CCodeReference)`, reading
  `reference_set_uri` directly from the parsed AM object — **no upstream gap here**,
  since #30 is fixed.
- `extract_code_bindings(document)` (`:259-280`) walks a **separately re-parsed raw XML
  document** (`Opt::SafeParser.safe_document(@template.source_xml)`,
  `app/lib/opt/safe_parser.rb:22-29`, Nokogiri with `NONET`, DOCTYPE rejected) via
  `document.xpath("//*[local-name()='term_bindings']")`, keyed by
  `[nearest_archetype_id(term_binding), item["code"]]` (`nearest_archetype_id`,
  `:282-289`: walks ancestors for the first `archetype_id` element). This bypasses
  `OPTParser` entirely because of `#31`.
- `primary_value_alternative(element)` (`:137-145`): when the `value` attribute has
  more than one constraint alternative, prefers the one whose `defining_code` is a
  `CCodeReference`, else falls back to `children.first`.
- **No removal-condition code comment exists in anlage** tying this bypass to `#31` —
  that management form lives only in anlage's design docs
  (`docs/design/pathcards-schema-v1.md:80,291`). The rails port below adds one, per
  this repo's convention of the same management shape
  (precedent: anlage `app/lib/opt/rm_composition_committer.rb:7`, a different issue).

## 4. Design decision: why the multi-alternative fix belongs in this issue

Anlage's real `ProblemList.opt` (CKM public archetype, Archetype Designer, human
authored — catalogued `anlage/docs/demo/opt-catalog.md:23-25`) has, on its
`problem_diagnosis.v1` at0002 ELEMENT, a `value` attribute with **two** constraint
alternatives (verified directly, `ProblemList.opt:285-336`): a `DV_TEXT` alternative
first, then a `C_CODE_REFERENCE`-constrained `DV_CODED_TEXT` alternative
(`referenceSetUri: terminology:http://id.who.int/icd/release/11/mms`) second.
`FieldExtractor#value_constraint` (`field_extractor.rb:174-178`) takes
`attrs.find{...}.children&.first` unconditionally. Without alternative selection,
`value_set_uri` would come back `nil` on exactly the real-world OPT shape motivating
this issue — the feature would be vacuous on day one. **Decision (user-arbitrated
2026-08-25): port `primary_value_alternative` into this same issue**, not a follow-up.

## 5. Fix approach

### 5.1 Parse-time enrichment in `OpenehrRails::Opt::Parser`

Add a private `populate_term_bindings!` (or similarly named) step to `#parse`
(`lib/openehr_rails/opt/parser.rb`), called after `defs = definition` (`:23`), before
`OperationalTemplate.new`. `@opt` (Nokogiri doc, **namespaces already stripped**,
`remove_namespaces!` at `:21`) and `@component_terminologies` are already held by this
point.

**Target shape** — populate the *existing* upstream slot
`component_terminologies[archetype_id].term_bindings`
(`ArchetypeOntology#term_bindings`, `ontology.rb:8`) in the same **in-memory** shape
`ArchetypeOntology` already expects: `{ terminology_string => { at_code =>
[CodePhrase, ...] } }` — this is the shape `term_binding(terminology:, code:)`
(`ontology.rb:70-72`) indexes into, and the shape `XMLArchetypeParser#ontology`
populates for ADL/XML archetype parsing (`xml_archetype_parser.rb:189`).

**Important correction from initial design sketches**: `XMLArchetypeParser`'s own
`ontology_bindings` helper (`xml_archetype_parser.rb:214-220`) cannot be reused
mechanically — it reads a *different* XML shape. ADL/XML-archetype `term_bindings`
elements are flat: `<term_bindings terminology="..." code="...">terminology::code
</term_bindings>` (attributes + a single qualified-reference text node, split by
`code_phrase_from_binding` at `xml_archetype_parser.rb:226-230`). **OPT's
`term_bindings` XML is structurally different** (verified directly against
`spec/templates/bmi_calculation_without_uid.opt:1683-1702`):
```xml
<term_bindings terminology="SNOMED-CT">
    <items code="at0004">
        <value>
            <terminology_id>
                <value>SNOMED-CT</value>
            </terminology_id>
            <code_string>[SNOMED-CT::60621009]</code_string>
        </value>
    </items>
</term_bindings>
```
— a `term_bindings[@terminology]` wrapping one-or-more `items[@code]/value` (a
serialized `CODE_PHRASE`: `terminology_id/value` + `code_string`, already in the
bracketed qualified form `[SNOMED-CT::60621009]` — no `::`-splitting needed, unlike
the ADL side). So the rails-side reader must walk OPT's own nested `items` structure
directly (mirroring anlage's `extract_code_bindings`, not
`XMLArchetypeParser#ontology_bindings`) and only needs to match the **target
in-memory shape**, not the source-XML-reading logic, for upstream compatibility.

**Archetype attribution**: verified directly (via a small ancestor-chain probe on the
bmi fixture) that a `term_bindings` element's nearest ancestor carrying an
`archetype_id/value` is the owning `children[@archetype_id]` node (i.e. the
`C_ARCHETYPE_ROOT`) — confirmed for `openEHR-EHR-OBSERVATION.body_mass_index.v2`'s own
`term_bindings`. So: `node.ancestors.each { |a| v = a.at_xpath('./archetype_id/value');
return v.text if v }` (plain XPath is fine — no `local-name()` needed, since `@opt` has
namespaces stripped; anlage's `local-name()` form was needed only because anlage kept
namespaces). This nearest-first walk also correctly attributes bindings inside embedded
`C_ARCHETYPE_ROOT`s to the embedded archetype, consistent with issue #25's per-element
archetype_id threading.

**Method sketch**:
```ruby
# 撤去条件: openehr-ruby#31（OPTParser drops term_bindings）の上流解消後。
# 上流OPTParserがcomponent_terminologiesの各ArchetypeTerminologyへ
# term_bindingsを投入するようになれば、下のnilガードで本メソッドは
# no-opになるため、このメソッド群と#parseからの呼び出しを削除する。
# それまでは、OPT文書のterm_bindings（items/valueの入れ子構造。ADL/XML
# アーキタイプのterm_bindings ── 属性+単一テキストの平坦構造 ──とは
# XML構造が異なる点に注意）を@optから直接読み、上流ArchetypeOntology#
# term_bindingsと同じ正規形 { terminology => { code => [CodePhrase] } }
# へ投入する暫定バイパス。
def populate_term_bindings!
  raw_term_bindings_by_archetype.each do |archetype_id, bindings|
    terminology = (@component_terminologies || {})[archetype_id]
    next unless terminology
    next if terminology.term_bindings # already populated upstream (#31 fixed) -> no-op

    terminology.term_bindings = bindings
  end
end

def raw_term_bindings_by_archetype
  @opt.xpath('//term_bindings').each_with_object({}) do |tb, by_archetype|
    archetype_id = nearest_archetype_id(tb)
    next unless archetype_id

    system_uri = tb['terminology']
    tb.xpath('./items').each do |item|
      code_phrase = binding_code_phrase(item, system_uri)
      next unless code_phrase

      ((by_archetype[archetype_id] ||= {})[system_uri] ||= {})[item['code']] ||= []
      by_archetype[archetype_id][system_uri][item['code']] << code_phrase
    end
  end
end

def binding_code_phrase(item, fallback_terminology)
  code_string = item.at_xpath('./value/code_string')&.text
  return nil if code_string.nil? || code_string.empty?

  terminology_text = item.at_xpath('./value/terminology_id/value')&.text
  terminology_text = fallback_terminology if terminology_text.nil? || terminology_text.empty?

  OpenEHR::RM::DataTypes::Text::CodePhrase.new(
    terminology_id: OpenEHR::RM::Support::Identification::TerminologyID.new(value: terminology_text),
    code_string: code_string
  )
end

def nearest_archetype_id(node)
  node.ancestors.each do |ancestor|
    value = ancestor.at_xpath('./archetype_id/value')
    return value.text if value
  end
  nil
end
```
(Exact method names/placement to be finalized during implementation; the shape,
XPath structure, attribution logic, and removal-condition comment are the fixed
requirements.)

### 5.2 `FieldExtractor` read side

Both new keys are **always present** on every field (arbitrated shape;
also structurally required — the BMI fixture's `term_bindings` attach to a
`DV_QUANTITY` element (height, at0004) as well as `DV_CODED_TEXT`, so `code_bindings`
cannot be restricted to coded fields):

- `build_field` (`field_extractor.rb:152-172`): add `value_set_uri: nil` and
  `code_bindings: code_bindings_for(archetype_id, element.node_id)` to the base hash
  (the `nil` default is overwritten by `coded_text_constraints`'s merge when
  applicable, matching the existing `code_list`/`code_labels` pattern).
- `coded_text_constraints` (`field_extractor.rb:191-203`): add
  `value_set_uri: code_phrase.is_a?(OpenEHR::AM::OpenEHRProfile::DataTypes::Text::CCodeReference) ? code_phrase.reference_set_uri : nil`
  to the returned hash.
- New private `code_bindings_for(archetype_id, node_id)`:
  ```ruby
  def code_bindings_for(archetype_id, node_id)
    terminology = @template.component_terminologies[archetype_id]
    bindings = terminology.respond_to?(:term_bindings) ? terminology.term_bindings : nil
    return [] unless bindings

    bindings.flat_map do |system_uri, codes|
      Array(codes[node_id]).map { |code_phrase| { system_uri: system_uri, code: code_phrase.code_string } }
    end
  end
  ```
  Nil-safe for hand-built `OpenStruct` templates in existing doubles-based specs
  (`field_extractor_section_spec.rb`, `_ordinal_spec.rb`, `_concept_slug_spec.rb`) and
  for archetypes with no terminology entry. `code:` keeps the **raw** `code_string`
  (bracketed qualified form, e.g. `[LOINC::8302-2]`) — matches anlage's golden fixture
  contract; normalization is explicitly deferred (§7).
- `value_constraint` (`field_extractor.rb:174-178`): port
  `primary_value_alternative` — when the `value` attribute's children has more than
  one entry, prefer the child whose `defining_code` constraint `is_a?(CCodeReference)`,
  else fall back to `children.first`:
  ```ruby
  def value_constraint(element)
    attrs = element.attributes || []
    value = attrs.find { |a| a.rm_attribute_name == 'value' }
    children = value&.children || []
    return children.first if children.size <= 1

    code_reference_class = OpenEHR::AM::OpenEHRProfile::DataTypes::Text::CCodeReference
    children.find { |child| defining_code_of(child).is_a?(code_reference_class) } || children.first
  end
  ```
  (`defining_code_of` factors the `attributes.find{rm_attribute_name=='defining_code'}
  .children&.first` lookup already duplicated between `value_constraint`'s new logic
  and `coded_text_constraints`.) **Side effect**: for a multi-alternative element, the
  chosen alternative's `rm_type_name` (hence `column_type`) can change from `DV_TEXT` to
  `DV_CODED_TEXT`. No existing fixture has multi-alternative `value` constraints, so no
  existing spec's expected values change — call this out in `CHANGELOG.md` for future
  templates.
- Update the class doc comment (`field_extractor.rb:8-21`) to list the two new keys.

### 5.3 `ProfileGenerator`

`apply_value_constraints`'s `DV_CODED_TEXT` branch (`fhir/profile_generator.rb:125-128`)
restructured:
```ruby
when 'DV_CODED_TEXT'
  has_local_codes = !(field[:code_list].nil? || field[:code_list].empty?)
  return unless has_local_codes || field[:value_set_uri]

  element[:binding] = { strength: 'required' }
  element[:binding][:valueSet] = field[:value_set_uri] if field[:value_set_uri]
```
Resulting cases: (a) local `code_list` only → `{ strength: 'required' }`, unchanged
(regression-pin spec); (b) `C_CODE_REFERENCE` (even with empty `code_list`) →
`{ strength: 'required', valueSet: uri }` — today this element gets **no** `binding`
at all, so this is the bug-repro red case; (c) neither → no `binding` key, unchanged.
`valueSet` carries `reference_set_uri` verbatim (e.g.
`terminology:http://id.who.int/icd/release/11/mms`) — no scheme normalization (§7).

### 5.4 Dependency floor

- `openehr-rails.gemspec:31`: `gem.add_dependency('openehr', '~> 2.3', '>= 2.3.1')` —
  2.3.0 crashes parsing `C_CODE_REFERENCE` (#30, fixed 2.3.1); this compound constraint
  raises the floor without forcing `~> 2.4` (no 2.4-only API is used).
- **All four lockfiles** move together: `Gemfile.lock:201` plus
  `gemfiles/rails_{7_2,8_0,8_1}.gemfile.lock` (all currently pin `openehr 2.3.0`) —
  `bundle update openehr` (expected to resolve to 2.4.2, the current release). Missing
  one leaves a CI leg crashing on the new fixture instead of exercising the new
  behavior.

## 6. Fixture

**Decision (user-arbitrated 2026-08-25): copy anlage's real `ProblemList.opt`
wholesale** into `spec/templates/problem_list.opt`, rather than hand-reducing it — this
repo's convention flags "opt files must not be changed automatically" and treats
hand-editing OPT XML as the error-prone step to avoid; a byte-identical copy with a
provenance comment has zero reduction risk and the file conveniently carries both the
`C_CODE_REFERENCE` case (at0002) and a local-`code_list` contrast case (at0073) in one
fixture. Kind: **real**. Leading XML comment (provenance "as measured", per
convention):

```
<!--
  Real fixture (kind: real). Byte-identical copy, below this comment, of Anlage's
  spec/fixtures/opt/ProblemList.opt (sha256 of the unmodified source file:
  b821b98beebfba9e758cc0429a91bb98aedb7d50de684424f0eb58d51e4a47c1; catalogued in
  anlage docs/demo/opt-catalog.md). Human-authored via Archetype Designer from CKM
  public archetypes (2026-08-22, frozen in anlage); language ja. Copied here (issue
  #30) as this repository's first fixture carrying a C_CODE_REFERENCE/referenceSetUri
  (value_set_binding, EVALUATION.problem_diagnosis.v1 at0002, ICD-11 MMS) alongside a
  local code_list (at0073) — only this comment was prepended; the XML body below is
  unmodified.
-->
```
(sha256 computed directly via `sha256sum` against anlage's fixture, 2026-08-25.)

If `spec/templates/problem_list.opt` fails to parse under `openehr` 2.4.x during the
red phase (untested combination — flagged as a risk, not expected), fall back to a
**reduced** fixture (`problem_list_reduced.opt`, trimmed to the `problem_diagnosis`
entry, kind `reduced`, provenance naming the same source + sha256) rather than blocking
on it.

`code_binding` needs **no new fixture** — `spec/generators/templates/bmi_calculation.opt`
and `spec/templates/bmi_calculation_without_uid.opt` already carry 4 real SNOMED-CT/
LOINC `term_bindings` (verified: LOINC 8302-2 on height at0004 `:721-730`; LOINC
29463-7 on weight `:1215-1224`; SNOMED-CT `[SNOMED-CT::60621009]` and LOINC
`[LOINC::39156-5]` both on body_mass_index at0004 `:1683-1702`). Reusing these respects
the arbitrated SNOMED-literal budget (no new real code strings enter the repo;
`problem_list.opt`'s binding is a value-set URI, not a code).

## 7. TDD plan (t-wada: red before green)

Ordered within one branch:

1. **Dependency-floor prerequisite** (new spec, e.g.
   `spec/openehr_rails/opt/parser_spec.rb` addition or a dedicated spec): "parsing
   `problem_list.opt` does not raise". **Red** under the current lock (openehr 2.3.0 —
   parse-time crash, #30). **Green** after the gemspec floor + all four lockfile
   bumps (bump alone changes no rails runtime behavior — run the *full* existing suite
   in this commit to confirm).
2. `spec/openehr_rails/opt/parser_term_bindings_spec.rb` (new; **enhancement**,
   spec comment states this). Parses `bmi_calculation_without_uid.opt` and asserts
   `component_terminologies['openEHR-EHR-OBSERVATION.body_mass_index.v2']
   .term_bindings` equals the canonical shape: `'SNOMED-CT' => {'at0004' => [a
   CodePhrase with code_string '[SNOMED-CT::60621009]', terminology_id.value
   'SNOMED-CT']}`, `'LOINC' => {'at0004' => [code_string '[LOINC::39156-5]']}` — plus
   parity between file-path and raw-XML-content parsing (`Opt::Parser` supports both,
   `parser.rb:14-19`). **Red**: `term_bindings` is `nil` today (`NoMethodError` on
   `[]`). Spec comment: this pins the contract §5.1's bypass must satisfy so it can be
   deleted cleanly once `skoba/openehr-ruby#31` lands upstream.
3. `spec/openehr_rails/opt/field_extractor_binding_spec.rb` (new; **enhancement**).
   BMI context: height field (`DV_QUANTITY`, non-coded) has
   `code_bindings == [{system_uri: 'LOINC', code: '[LOINC::8302-2]'}]` (proves
   extraction isn't DV_CODED_TEXT-only); body_mass_index at0004 field has
   `code_bindings` containing both the SNOMED-CT and LOINC entries in document order;
   every field responds `true` to `key?(:value_set_uri)` and `key?(:code_bindings)`.
   problem_list context: at0002 field has `value_set_uri ==
   'terminology:http://id.who.int/icd/release/11/mms'`, `rm_type == 'DV_CODED_TEXT'`
   (pins alternative selection), `code_list == []`; at0073 field has `value_set_uri ==
   nil` and a non-empty `code_list` (**regression pin** — green at birth, comment says
   so explicitly). One `OpenStruct`-built double example confirms nil-safety
   (`value_set_uri: nil, code_bindings: []`). **Red**: keys absent /
   `rm_type == 'DV_TEXT'`.
4. `spec/openehr_rails/fhir/profile_generator_spec.rb` extension (**bug** — spec
   comment: "red repro for issue #30's valueSet omission"). With `problem_list.opt`:
   the problem_diagnosis element's `binding` includes
   `{ strength: 'required', valueSet: 'terminology:http://id.who.int/icd/release/11/mms' }`.
   **Red today** (post dependency-floor bump): no `binding` key at all is emitted
   (`profile_generator.rb:126`'s early return). Companion **regression pin**: the
   at0073-equivalent local-`code_list` binding stays exactly
   `{ strength: 'required' }` (no `valueSet` leak).
5. Implement §5 (green). Refactor pass: factor the `defining_code`-child lookup shared
   between `value_constraint` and `coded_text_constraints`; confirm doc comments
   (`field_extractor.rb:8-21`) match the shipped keys. Run the **full** suite —
   existing `field_extractor_*_spec.rb` family, `fhir/serializer_spec.rb` (reads only
   `terminology_id`/`code_labels` — additive keys are inert), `storable`/scaffold
   generator specs (`FIELD_MAP` gains two inert keys), `spec/unit/opt_parser_spec.rb`
   — expected unchanged and green throughout.

## 8. Compatibility impact

- **Public API / field-hash contract change**: every `FieldExtractor` field hash gains
  two always-present keys. Additive — no existing key removed or retyped. Downstream
  code that does `field.keys == [...]` (none found in this repo) would be affected;
  none exists today.
- **FHIR output change**: `DV_CODED_TEXT` elements backed by `C_CODE_REFERENCE` now
  emit a `binding` where none was emitted before; local-`code_list` bindings are
  unchanged. **Host apps with cached `app/fhir/profiles/*.json` must regenerate** to
  see this (`profile_repository.rb:15-19` serves the cache first) — call out
  explicitly in `CHANGELOG.md`.
- **Scaffolding output change (narrow)**: only for OPTs with a multi-alternative
  `value` constraint choosing a `C_CODE_REFERENCE` alternative — `rm_type`/
  `column_type` can change from `DV_TEXT` to `DV_CODED_TEXT`. No existing fixture
  exercises this; flag for template authors in `CHANGELOG.md`.
- **Install-time dependency**: `openehr` floor raised from (effectively) `2.3.0` to
  `>= 2.3.1` — this alone is already `patch`-or-above per this repo's semver
  convention (it changes what host apps must have installed); combined with the field
  additions and FHIR output fix, propose **minor** (`0.4.1` → `0.5.0`,
  `lib/openehr_rails/version.rb:4`) — new field-hash keys are new public API surface,
  not just an internal fix. Final semver call happens at tag time from actual
  `[Unreleased]` content, per convention; this repo does not tag as part of this
  issue/PR (recorded for the later release inventory).
- **`CHANGELOG.md`** (`[Unreleased]`, to be written at merge time):
  - `### Added` — `field[:value_set_uri]` / `field[:code_bindings]` on every
    `FieldExtractor` field; interim `term_bindings` parse-time bypass in
    `OpenehrRails::Opt::Parser` (removal-condition: `skoba/openehr-ruby#31`).
  - `### Fixed` — `ProfileGenerator` `DV_CODED_TEXT` `binding.valueSet` for
    `C_CODE_REFERENCE` constraints (previously no `binding` at all for such elements;
    local-`code_list` bindings never carried `valueSet` regardless). Note: host apps
    must regenerate cached `app/fhir/profiles/*.json`.
  - `### Changed` — `openehr` dependency floor raised to `>= 2.3.1` (2.3.0 crashes
    parsing `C_CODE_REFERENCE`, `skoba/openehr-ruby#30`). Lockfiles moved to 2.4.2.

## 9. Deferred (recorded, not fixed in this issue)

- `term_bindings` `items@code` in path form (rather than a bare at-code): never
  matches a `node_id` lookup and is silently dropped — identical to anlage's reference
  behavior (`item["code"]` used directly). Not handled in v1.
- `term_bindings` attached to an entry root itself (at0000-style), rather than to a
  descendant `ELEMENT`: `fields[]` only ever covers `ELEMENT`s, so such bindings are
  never surfaced. Consistent with anlage's own scope.
- `valueSet` scheme normalization (the `terminology:` prefix passed through verbatim):
  out of scope; FHIR validators may flag it, but arbitration is to pass it through as
  the raw `reference_set_uri`.
- `code_bindings[:code]` normalization (bracketed qualified form kept raw): deferred —
  becomes a published contract for the future `FshGenerator`; changing it later is a
  breaking change to a published field key, so this choice should be revisited
  deliberately if/when FSH work needs bare codes, not silently changed.
- If `skoba/openehr-ruby#31`'s eventual upstream fix populates `term_bindings` in a
  shape other than `{ terminology => { code => [CodePhrase] } }`, the removal of §5.1's
  bypass may need a one-time shape adapter rather than a pure two-line deletion; the
  pinned spec (`parser_term_bindings_spec.rb`) will fail loudly if so, at the gem-bump
  PR that raises the floor past whatever release fixes #31.

## 10. Stop point

This document covers explore + design only, per the ticket-driven workflow. Do not
implement until this design doc is committed and reported to the user as a gate.
Next steps after approval: branch (1 issue = 1 branch = 1 PR), hand off to Codex for
implementation against §5–7 above, then Claude Code review of the diff against this
plan, full `bundle exec rspec` run, commit(s) with `Implemented-by: Codex` trailer,
PR closing with `Fixes #30`. Release (whether this ships in `0.5.0`) is decided later,
independently, at the release inventory — not part of this PR.

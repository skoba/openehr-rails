# Security fixtures

Kind: **security**. These files exercise attack cases, not clinical data, and
are not openEHR artifacts. They were made for #133 (R-20261128-13), modelled on
openehr-ruby's `spec/lib/openehr/parser/security_fixtures/` (read only).

- `xxe_sentinel.txt`: the text an XXE payload tries to read.
- `xxe_external_dtd.dtd`: an external DTD subset that defines an entity.

`spec/openehr_rails/opt/parser_xxe_spec.rb` builds its payloads from the real
`spec/generators/templates/bmi_calculation.opt`. It adds a DOCTYPE and puts
the entity in `template_id`, so the attack goes through the whole OPT reader.

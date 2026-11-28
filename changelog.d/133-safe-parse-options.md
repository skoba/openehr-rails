### Security

- `OpenehrRails::Opt::Parser` passes the openehr gem's
  `OpenEHR::Parser::Base::SAFE_PARSE_OPTIONS` (RECOVER | NONET | BIG_LINES,
  without NOENT or DTDLOAD) to Nokogiri by name when reading an OPT (#133). It
  relied on Nokogiri's defaults, which are the same value, so behaviour does
  not change. Specs now pin that an OPT read or uploaded through the admin
  screen (`TemplateUploader`) resolves no external entity and loads no
  external DTD subset.

semver: patch. Hardening with no change in behaviour.

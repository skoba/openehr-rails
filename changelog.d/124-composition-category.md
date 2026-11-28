### Fixed

- A committed `COMPOSITION.category` is stored (#124), in the existing
  `category_code` / `category_value` columns of `openehr_rm_compositions`
  (no migration), and returned as committed by REST and `to_rm`. A persistent
  (`431`) composition committed through `/v1` used to come back as event
  (`433`). A composition committed without a category keeps the configured
  default (`OpenehrRails.default_category`), and REST still writes none for it.
- The default category rebuilt by `to_rm` had its code and text swapped
  (`code_string` `event`, value `433`); it is now `433` / `event`.
- Whether a context given only by `context_start_time:` is added to REST
  (#121) now follows the committed category, falling back to the configured
  one: a persistent composition gets no added context.

Rows stored before this release have no category in their columns and keep
reading as the configured default. AQL still cannot select `c/category` (an
openehr gem limitation).

semver: minor (with #121). A bug fix, but REST responses gain `category`,
and `to_rm` callers reading the default category see the corrected order.

### Added
- The AQL console (`GET /query`) opens with a query filled in when the URL
  carries `q` (and optionally `query_parameters`, as a JSON string), so another
  page can link to it, e.g. with an EHR's `ehr_id` in the query. Opening the page
  does not run the query; the button still does. Values are HTML-escaped; each
  is taken only as a string of at most 10,000 characters, and the page says so
  when one is longer. Without these parameters the console is unchanged (#94).

<!-- semver: minor. A new optional URL parameter on an existing page (public
API addition); nothing that worked before behaves differently. -->

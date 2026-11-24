<!-- semver: patch on its own (values that were silently dropped are now stored and
     rebuilt; no schema change, the columns already exist). Covers proposals 1 and 2
     of #46 only. -->

### Fixed
- `CompositionCommitter` / `GraphBuilder` persist a canonical composition's
  `context.start_time` (into `context_start_time`) and `context.setting` (into the
  already-existing `setting_code` / `setting_value` columns); they were dropped unless
  the caller passed `context_start_time:`. An explicit `context_start_time:` still
  wins. `RmObjectBuilder` rebuilds the stored setting instead of always `other`
  (#46, proposals 1-2; anlage upstream 16).

### Known limitations
- **Upgrade note.** `SELECT c/context/start_time/value` (and `c/context/setting/...`)
  is still not answerable: openehr 2.4.3's AQL path evaluator cannot navigate
  `EVENT_CONTEXT` and raises `unsupported path attribute "start_time"` as soon as a
  composition has a context. That was already the case for every `Storable`-saved
  composition; a composition committed from canonical JSON **with** a context now
  behaves the same way, where it used to yield a row holding `nil`.
- `context.other_context` is not persisted, and `CanonicalSerializer` does not emit
  `context` yet (#46 stays open for both).

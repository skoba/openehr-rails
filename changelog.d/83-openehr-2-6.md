### Changed
- **Upgrade note.** Requires `openehr` `~> 2.6, >= 2.6.1` (was `~> 2.5`): a host
  app locked to openehr 2.5.x or 2.6.0 must update it together with this gem. With
  it, AQL reaches `c/context/start_time` (#46), `c/archetype_details/template_id`
  (#64) and `c/uid/value` (#83).

<!-- semver: minor (0.x). The dependency floor moves; host apps must update openehr. -->

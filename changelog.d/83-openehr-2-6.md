### Changed
- **Upgrade note.** Requires `openehr` `~> 2.6` (was `~> 2.5`): a host app locked
  to openehr 2.5.x must update it together with this gem. With 2.6, AQL reaches
  `c/context/start_time` (#46) and `c/archetype_details/template_id` (#64) (#83).

<!-- semver: minor (0.x). The dependency floor moves; host apps must update openehr. -->

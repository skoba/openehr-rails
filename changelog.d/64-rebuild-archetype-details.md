### Fixed
- `Composition#to_rm` rebuilds `archetype_details` (`archetype_id` from the root's
  `archetype_node_id`, `template_id`, `rm_version`) from the stored row; it used to
  be nil, so the template a record came from was unreachable. With openehr 2.6.0
  or later, `SELECT c/archetype_details/template_id/value` answers it. A root
  node id that is not a valid archetype id rebuilds with `archetype_details` nil,
  as before (#64, anlage upstream 25).

<!-- semver: patch. Read-back gains a value it used to drop; nothing stored or
     accepted changes. -->

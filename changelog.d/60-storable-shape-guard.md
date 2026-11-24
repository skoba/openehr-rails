<!-- semver: minor (0.x). A save that used to write a malformed composition silently
     now raises. -->

### Changed
- **Upgrade note.** `OpenehrRails::Storable` raises
  `OpenehrRails::Storable::UnsupportedTemplateShape` on save, and saves nothing, when a
  record holds a value for a field it cannot assemble into a valid composition: a field
  of an entry nested in a `SECTION`, a field under an embedded archetype root, or a
  field of an `INSTRUCTION`. Until now such a save succeeded and stored a malformed
  `rm_composition` (no SECTION and a stray `items` level; the embedded root as a second
  bogus entry). The error names the shape, the fields and the tracking issue
  (#62, #61, #69). Records that leave those fields empty, and models of templates
  without these shapes, save exactly as before. Models generated before 0.9.0 are
  covered too (#60).
- `openehr:scaffold` prints a warning listing the fields of such shapes when it
  generates the model (#60).

### Known limitations
- `Storable` cannot yet write entries nested in a `SECTION` (#62), fields under an
  embedded archetype root (#61) or `INSTRUCTION` entries (#69); it refuses them as
  described above. Committing a canonical composition through
  `Rm::CompositionCommitter` is unaffected.

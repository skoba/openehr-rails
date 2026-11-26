### Changed
- The gem ships only what a host application runs: `lib/` (generator templates
  included), `app/`, `config/`, `README.md`, `CHANGELOG.md`, `LICENSE` and the
  gemspec. `spec/` (OPT fixtures), `docs/`, `doc/`, `demo_assets/`, scripts and
  CI/tooling files are no longer packaged. Measured on 0.11.0's tree: 201 -> 84
  files, 354,304 -> 80,384 bytes. The application template
  (`templates/openehr_template.rb`) is used from the repository URL and is not
  packaged either (#74).

<!-- semver: patch. Packaging only; nothing the engine or the generators read at
     runtime is dropped (spec/openehr_rails/gem_files_spec.rb). -->

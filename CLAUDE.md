# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Principle

Follow the TDD framework as advocated by t-wada:
- 🔴 Red: Write a failing test
- 🟢 Green: Write the minimal implementation to pass the test
- 🔵 Refactor: Improve the code while keeping tests green
- Take small steps
- Start with fake implementation (hard-coded values)
- Use triangulation to generalize
- Direct implementation is OK when the solution is obvious
- Keep the test list constantly updated
- Write tests for areas of concern first
- opt files must not be changed automatically.

## Ticket-driven workflow

- A change touching runtime behavior, public API, or install-time dependencies requires
  a GitHub Issue filed before work starts — no code-change commit without one. Changes
  limited to docs, CI, or dev-tooling config are Issue-optional.
- **This repo's surface for that rule is not just `lib/`**: `lib/generators/**/templates/`
  (the migrations and scaffolding code shipped to, and expanded inside, host
  applications) is shipped product too. Changes there are Issue-required and subject to
  the same semver judgment as any other runtime-behavior change.
- Write Acceptance criteria in a spec-verifiable form.
- Three resolution kinds, signaled in the PR body and in spec comments:
  - **bug** — a reproduction spec goes red first, then gets fixed green.
  - **enhancement** — a new-behavior spec goes red first, then gets implemented green.
  - **pin/hardening** — fixing an existing property in place, where red isn't possible.
    Mark this `regression pin` in a spec comment instead of staging a fake red.
- 1 issue = 1 branch = 1 PR (reaffirms the existing convention); the PR closes with
  `Fixes #N`. A `docs/design/` plan doc opens with the issue number.

## Working with implementation agents (e.g. Codex)

Codex delivers only working-tree changes; it does not commit. Claude Code reviews the
diff, then commits, recording the implementer in a commit message trailer (e.g.
`Implemented-by: Codex`).

## Release convention

Before tagging, make the final semver determination from the actual content of
the release (the `changelog.d/` fragments consolidated into `CHANGELOG.md` at the
inventory, checked against `git diff <last tag>..master` - see 全開の進め方 below),
not from a pre-assigned version number. If the instructed version number
contradicts the actual content, stop instead of tagging and ask for re-arbitration.

**Publish only the CI artifact itself.** `gem push` takes the `.gem` downloaded
from the tag's Release run (`gh run download <run-id> -n gem`), after its sha256
has been compared against the value recorded for that run - never a locally built
`pkg/*.gem`. `gem.files` comes from `git ls-files`, so a build made at any commit
other than the tag ships different bytes under the same version number, and a
stale `pkg/` artifact from unrelated local work is indistinguishable by filename
from a release build.

(Added 2026-08-27, from the 0.6.0 publish: the gem that reached RubyGems was a
`master`-HEAD build left in `pkg/` by an unrelated verification run, not the
CI-verified `v0.6.0` artifact. Accepted rather than yanked - the delta was two
documentation files and `lib/` was byte-identical - but nothing in the release
path caught it. Measurements in `docs/reports/fsh-generator-log.md` R8; the
matching `release:check` guard is `skoba/openehr-rails#34`.)

**Local dev Ruby tracks the patch release CI builds with.** `.ruby-version`
moved 4.0.6 -> 4.0.7 (2026-10-12) so a local rebuild at the tag stamps the same
`rubygems_version` (4.0.20) as `ruby/setup-ruby`'s ruby 4.0 image did for 0.7.1,
whose `metadata.gz` differed from the local rebuild by that one line
(`docs/reports/referral-upstream-log.md` R2). The cross-check still judges by
`data.tar.gz`, not the whole-gem sha256: the two toolchains can drift apart again.

**Confirm publication by checksum, not by version number.** RubyGems publishes
the sha256 it recorded at push time (`/api/v1/gems/openehr-rails.json` `sha`, and
the `checksum:` field in `https://index.rubygems.org/info/openehr-rails`). The
post-push confirmation compares that value against the sha256 the tag's Release
run recorded for its artifact - the same value already compared before the push.
Seeing the version number appear is not the check; it only shows that *a* gem
landed under that number. (Ported 2026-09-10 from openehr-ruby's 2.4.3 release,
where CI run, downloaded artifact and published gem all agreed on one sha256.)

**RubyGems API propagation lag.** `/api/v1/versions/openehr-rails.json` can lag
the push by minutes; do not read the new version's absence there as a failed
publish, and do not re-push. Confirm with
`/api/v1/versions/openehr-rails/latest.json`, `/api/v1/gems/openehr-rails.json`,
or the compact index `https://index.rubygems.org/info/openehr-rails`, which
updated first in that same 2.4.3 run.

## Verification

- **Verify against the repo before recording a fact in it**, even when a prompt or an
  earlier report already stated it as true - a premise that went unverified once tends
  to get repeated, not corrected, if the next write also skips checking (e.g. "CI is
  unconfigured" repeated across two turns before anyone ran `gh run list`).
- **The document a gate report points to must be pushed**, not just committed locally,
  before the report is sent - a local-only SHA is unverifiable by anyone reading the
  report. (Added 2026-08-25, after a gate report cited two docs-only commits - the #30
  issue-filing log and its design doc - that were still local-only `master` commits,
  not yet on `origin/master`.)
- **After a git command appears to lose a file, search git's own storage
  (`git stash show`/`stash@{n}^3`, `git reflog`, `git fsck --unreachable`) before
  reconstructing content from memory.** Reconstruction from a model's own memory of
  a file it recently read is a last resort, and if used, the result must be
  independently diffed against the recovered original before trusting it - matching
  by eye is not enough. (Added 2026-08-25, after a `git stash push -u` with a
  multi-pathspec argument printed a pathspec error for one untracked file and that
  file appeared to vanish from both the working tree and the stash's summary output;
  it was in fact captured in the stash's untracked-files commit the whole time - the
  error was cosmetic. The file was reconstructed from the session's own recent read
  before that was confirmed, and only verified byte-identical against the actual
  stashed copy afterward - the right outcome, but by the wrong order of operations.)

## Repository-context-dependent commands confirm their target explicitly

A command whose target (repository, branch, or resumed session) is decided by
ambient state - cwd, current branch, or session history - rather than an
explicit argument, must have that target pinned before it runs; never assume
the shell or session is still where an earlier step left it.

- If the tool has an explicit target option, always use it: `git` takes a `cd`
  to the intended directory on the same command line (or `-C <path>`); `gh`
  takes `-R <owner>/<repo>` (or `--repo`) on every invocation.
- If the tool has no such option (e.g. `codex exec`, `codex exec resume`),
  print `pwd` immediately before the call and confirm it names the intended
  repository first.
- Before adopting a new repository-context-dependent command for the first
  time, decide how this principle applies to it before using it.

(Generalized 2026-08-24, consolidating this repo's prior narrower
`checkout`/`pull` rule with `openehr-ruby`'s branch-confirmation rule, after a
third incident of the same class surfaced the need for one shared principle
covering non-git tools too. Three incidents on record: (1) this repo,
2026-08-22 - a mistaken `checkout`/`pull` ran against the wrong repo, caught
and self-reported immediately, no lasting effect; (2) `openehr-ruby`,
2026-08-23 - a docs-only commit intended for `master` landed on a
checked-out PR feature branch instead; (3) `anlage`, 2026-08-24 - `codex exec
resume --last`, run after cwd had silently drifted back to `openehr-ruby`,
resumed an unrelated stale session in the wrong repo instead of the intended
one; Codex itself detected the mismatch and made no changes, so there was no
lasting effect, but the near-miss is what prompted this generalization. See
`openehr-ruby`'s own copy of this rule and its `docs/backlog.md` entry
logging the underlying structural fix under consideration - one
worktree/session per repo instead of per-command vigilance.)

## Cross-repository implementation work needs its own authorization gate

The moment it becomes clear that the actual implementation target for a piece of
work is a repository other than this one, stop before starting that work and insert
a gate report confirming the implementation target, rather than sliding from
read-only cross-repo reference (already permitted for design/evidence-gathering)
into cross-repo write work on the strength of that same permission. Correctly
targeting a command once you've decided to cross the boundary (the previous
section's `cd`/`-C`/`-R` discipline) is a different concern from being authorized to
cross it at all - following the operational convention precisely does not retroactively
authorize the crossing.

(Added 2026-08-26, alongside the `#32`/`#33` FSH-generator work continuation, to
name explicitly a distinction that the existing repository-context rule left
implicit: it governs *how* to target a cross-repo command correctly, not *whether*
crossing into implementation work on another repository has actually been
authorized for the task at hand. A matching line is planned for `anlage`'s own
`CLAUDE.md` in a later batch - not yet added there as of this entry. Update
2026-09-04: added there as 絶対規律 item 9.)

## 裁定台帳(2026-11-20 導入)

- 統括の裁定の正典は `/home/skoba/src/anlage-ops/rulings.md`
  (非公開リポジトリ `skoba/anlage-ops`)。チャットに貼られた本文は写しで、
  食い違ったら台帳が正
- 「裁定 R-… を読んで着手」と言われたら、最初に
  `git -C /home/skoba/src/anlage-ops pull --ff-only` を実行し、
  台帳の該当行と本文を読む。読めなければ、着手せずに例外報告
- 着手したら、台帳の自分宛ての行の状態を 発行 → 着手 に書き換え、
  anlage-ops に commit・push する(日付と、あれば最初の push SHA)。
  anlage-ops に書いてよいのはこの 1 行だけ。ほかの行、本文、
  ほかのファイルは変えない。これは越境ゲートの例外として認められている
- 完了に進めるのは統括か人間。セッションは「完了申請(SHA、CI run)」まで書いてよい
- 報告とコミットメッセージには裁定 ID を書く(例: `Refs R-20261120-1`)
- anlage-ops の内容(裁定の本文、ロードマップ)を、このリポジトリのコード、
  Issue、PR、文書に写さない。参照は裁定 ID で行う

## 依存の方針(2026-11-24 導入。裁定 R-20261124-2)

要点だけを書く。正典は裁定台帳の R-20261124-2。

- 依存は最新のリリース版に追従する。`openehr-rails.gemspec` の下限と、手元・CI が
  解決する版を、理由なく古いままにしない
- 版を固定する、または上限を付けるときは、理由と解除の条件を、その行のコメントと
  Issue の両方に残す
- 依存の不具合は上流で直す。このリポジトリに置く迂回はつなぎで、撤去の条件を
  コードのコメントに書く(実例: `lib/openehr_rails/opt/parser.rb` の
  `populate_term_bindings!` と openehr-ruby#31)
- 未リリースのコードには、上流に修正があり、リリースを待てないときだけ依存する。
  SHA で固定し、リリースが出たら RubyGems の版に戻す
- 上流の Issue・PR への投稿は人間が行う。セッションは再現手順と文面の案を用意する
- 依存の更新は 1 件ずつ、CI の合否で決める。マージは人間

## 作業ツリー規律(2026-11-24 導入。裁定 R-20261124-6)

anlage の `CLAUDE.md`「作業ツリー規律」と同旨。根拠と採らなかった案は、anlage の
`docs/design/session-isolation-plan.md`(承認済み、R-20261123-1)。

- 1 セッション = 1 リポジトリ。起動ディレクトリがこのリポジトリでなければ、
  また宛先が別リポジトリの依頼なら、着手せずに止まる
- セッションの冒頭で `git fetch` と `git status --short` を実行する。
  未コミット物があれば、作業の前に一覧を報告の先頭に書く
- 実装は必ず git worktree で行う。置き場所は
  `/home/skoba/src/openehr-rails-worktrees/<slug>`(1 ブランチ = 1 worktree)。
  `/tmp` には作らない。本体の作業ツリーは `master` のまま動かさず、
  docs のみの直接 push と fetch にだけ使う
- 着手時に同じ slug の worktree が既にあれば、止まって例外報告する
  (worktree のパス、ブランチ、未コミット物の一覧を書く)。ログの記載だけを根拠に
  再開しない。例外は、裁定または人間の指示がその slug の再開を名指ししているときだけ
- セッションの終わりに作業ツリーを空にする。途中の作業は `wip/<slug>` ブランチに
  コミットして push する(draft PR でよい)
- 未コミット物を捨てるのは削除にあたり、ゲート対象
- コミットはパスを明示して add する(`-A` と `.` を使わない)
- 合否はクリーンな checkout(CI)で決める。並行負荷のある手元の結果を合否に使わない
- `master` への直接 push が non-fast-forward で拒否されたら、fetch して rebase する。
  force はしない
- 越境(読み取り)は、絶対パスと `git -C` で相手リポジトリの本体ツリーを読む
  (`log`・`show`・`grep`・ファイルの閲覧)。報告に対象リポジトリと SHA を書く。
  相手のツリーでは `checkout`・`pull`・`bundle`・`rspec` を実行しない。
  依存する gem の挙動は、自分の worktree で解決された版に対して確かめる。
  未リリースのコミットの挙動は、gem 側に Issue を立てて頼む。`Gemfile` を
  相手のツリーへの path 指定に書き換えたものをコミットしない
- Codex の納品先は、当該 Issue の worktree。本体ツリーには納品させない。
  起動の直前に `pwd` を出力して worktree であることを確かめる。
  `codex exec resume --last` は使わない。毎回あたらしく起動し、受け渡しは
  commit 済みの計画書で行う(上の「Repository-context-dependent commands…」の
  `codex exec resume` の扱いは、この項が上書きする)

## 全開の進め方(2026-11-24 導入。裁定 R-20261124-8)

要点だけを書く。正典は裁定台帳の R-20261124-8。これより前の記述と食い違うときは、この節が優先する。

- **止まらずに進める範囲**: 承認済みの計画書と、このリポジトリ宛ての作業列にある項目。
  計画書が要る項目は、計画書を push してそのまま実装に進む(確認は事後)
- **必ず止まってゲート報告を出す範囲**: 計画書に無い挙動の変更と公開 API の変更。
  gem の追加と未リリースのコードへの依存。データの移行と削除、開発機の設定の変更。
  臨床の判断と人間の入力を待つもの。タグと publish。ほかのリポジトリへの書き込み
  (台帳の自分宛ての行は除く)
- **セッションが自分でマージしてよい PR**: 自分で開いた、docs のみの PR と、
  止まらずに進める範囲の実装の PR。条件は、head の CI がすべて green、競合なし、
  1 Issue = 1 PR。マージのあと `master` の CI を確かめ、赤なら次に進まず例外報告。
  `master` では force-push と履歴の書き換えをしない
- **人間がマージする PR**: 依存を変えるもの(`Gemfile`、gemspec、lock)、版番号を
  変えるもの、CI のワークフローを変えるもの、ファイルの削除が主な中身のもの、
  必ず止まる範囲に当たったもの。権限でマージが止められたら、回避せずに報告する
- **変更履歴は断片ファイル**: PR では `CHANGELOG.md` に触らない。
  `changelog.d/<Issue 番号>-<slug>.md` を 1 PR につき 1 つ足し、変更履歴の文と
  semver の判定・理由を書く。棚卸しで断片を `CHANGELOG.md` にまとめ、断片を消す
  (タグの時点で `changelog.d/` に断片が残っていないこと)
- **公開はできた順**: 公開できる中身が `master` にそろったら棚卸しに進む。
  手順は Release convention のとおりで、変えない
- **報告**: ゲート・バンドル・例外の報告は `docs/reports/` に push し、台帳の自分宛ての
  行に PR 番号と SHA を書き足す。次の裁定を待たずに、作業列の次の項目に進む
- **変えないもの**: TDD(Red の出力を報告に載せる)、合否は CI、実測と推論の区別、
  越境は読み取りだけ、publish は CI artifact だけで `gem push` は人間

## Project Overview

This is `openehr-rails`, a Rails engine gem that turns an openEHR Operational Template (`.opt`, ADL2/XML) into a working Rails resource in one command: `rails generate openehr:scaffold path/to/template.opt --fhir` emits a model, migration, controller, views, i18n locale, and (with `--fhir`) HL7 FHIR R5 `StructureDefinition` profiles. Generated models persist both as typed columns (for forms/search) and as full openEHR RM data (canonical JSON + a typed node graph with immutable-append versioning), and are queryable via a growing AQL surface. A mountable admin engine (`/openehr`) provides template upload/management, runtime scaffolding, and a FHIR R5 facade. Legacy ADL-archetype-only generators (model/controller/migration/helper/assets/i18n/template/template_model, based on `Openehr::Generators::ArchetypedBase`) have been removed — OPT is the only supported input format for scaffolding.

## Key Commands

**Testing:**
- `rake spec` - Run all RSpec tests
- `rake` - Default task runs specs
- `bundle exec rspec spec/path/to/specific_spec.rb` - Run specific test file

**Development:**
- `bundle install` - Install dependencies
- `bundle exec rake` - Run tests via bundler
- `bundle exec guard` - Run Guard for automated testing (requires guard-rspec)

**Gem Development:**
- `rake build` - Build the gem (via bundler/gem_tasks)
- `rake install` - Install the gem locally
- `rake release` - Release the gem

**Demo app** (reproducible, git-ignored): `bash script/build_demo.sh` builds a Rails 8 app in `demo/` from the OPTs and seed data in `demo_assets/`, scaffolding three templates (BMI, problem list, blood pressure) with FHIR profiles. See `doc/DEMO_ja.md` for the full walkthrough.

## Architecture & Structure

### Generators (`lib/generators/openehr/`)

- `install/` - one-time setup: mounts the engine at `/openehr`, creates the `OpenehrTemplate` registry model and the `openehr_ehrs` / `openehr_rm_*` RM persistence tables.
- `scaffold/` - the core generator. Takes an `.opt` file (or, per the roadmap, a remote URL), parses it via `OpenehrRails::Opt::Parser`, extracts fields via `OpenehrRails::Opt::FieldExtractor`, and emits model/migration/controller/views/locale/request-spec/routes. `--namespace` and `--fhir` options available.
- `fhir_profile/` - emits FHIR R5 `StructureDefinition` JSON per OPT entry into `app/fhir/profiles/`.

### Runtime library (`lib/openehr_rails/`)

- `opt.rb`, `opt/parser.rb`, `opt/field_extractor.rb` - OPT parsing (subclasses `OpenEHR::Parser::OPTParser` from the `openehr` gem) and flattening of ENTRY/ELEMENT constraints into field hashes (`FIELD_MAP` is the single source of truth tying a generated column to an RM path + data type).
- `storable.rb` - mixed into scaffolded models (`OpenehrRails::Storable`): on save, builds a canonical openEHR RM Composition from `FIELD_MAP`, caches it as JSON (`rm_composition` column), and persists it into the RM graph.
- `rm/` - the RM persistence layer: `Composition`/`Node`/`DataValue` (STI, `openehr_rm_*` tables), `GraphBuilder` (canonical JSON → graph rows), `CanonicalSerializer` (graph → canonical JSON, round-trip invariant), `GraphPersister` (immutable-append versioning), `RmObjectBuilder` (graph → real `OpenEHR::RM` objects), `Ehr`/`Contribution`/`Version` (audit trail).
- `aql_queryable.rb` - `Model.find_by_path` (FIELD_MAP lookup with RM-graph fallback); full AQL query support is planned to build on the same path-to-column resolution (see roadmap in the project's plan history).
- `template_registry.rb`, `template_uploader.rb`, `runtime_scaffolder.rb` - the `OpenehrTemplate` model (supports both OPT and legacy ADL archetype registration) and the admin engine's upload + in-process `openehr:scaffold` invocation.
- `fhir/` - FHIR R5 facade: profile generation, canonical-RM ⇄ FHIR serialization, resource registry, capability statement, served at `/openehr/fhir` by `app/controllers/openehr_rails/fhir_controller.rb`.

### Testing Structure

- RSpec with `ammeter` for generator specs; in-memory SQLite (`spec/support/active_record.rb`) for RM-layer specs.
- `spec/generators/openehr/{install,scaffold,fhir_profile}/` - generator specs (only these three generators remain).
- `spec/openehr_rails/{opt,rm,fhir}/`, `spec/openehr_rails/*_spec.rb` - runtime library specs.
- `spec/models/openehr_template_spec.rb`, `spec/unit/opt_parser_spec.rb` - registry model and parser specs.
- OPT fixtures live in `spec/generators/templates/` and `spec/templates/`; do not hand-edit an existing `.opt` fixture (add a new one instead) — **opt files must not be changed automatically.**
- Fixtures fall into four kinds; each fixture's leading comment must say which kind it is:
  - **real** — a genuine artifact (CKM export, Archetype Designer output, a real host-app
    template), used as-is.
  - **reduced** — a trimmed-down real artifact; the comment must name the real source it
    was reduced from.
  - **synthetic** — hand-authored, not derived from any real artifact. real/reduced are
    preferred by default; synthetic is only for structural test cases whose reproduction
    conditions can't be controlled with a real artifact. The leading comment must say it's
    synthetic and cite its design authority (e.g. a design doc section). Archetype
    IDs/at-codes should use self-evidently invented names that can't be mistaken for real
    ones — don't rename an existing fixture to fix this after the fact; its at-codes/
    archetype IDs are reference anchors other specs/docs already point to, and freezing
    those anchors takes priority.
  - **security** — built to exercise an attack/abuse case; the comment must say it is not
    a clinical artifact.
  - A fixture's provenance comment must describe its lineage as measured (checked against
    the actual design/implementation record), not as instructed — if an instructed lineage
    doesn't match what actually went into the fixture, write it to match reality instead.
  - Example: `spec/templates/lab_result_report_reduced.opt` is **synthetic** (design
    authority: `docs/design/fix-terminology-scope-plan.md` §4; lineage confirmed
    2026-08-22) — its filename says "reduced" for historical reasons, but per this
    convention its actual kind is synthetic; the name stays as-is (reference anchor).

## Development Notes

- Ruby 3.3+ required (raised from 3.0 in 2026-08 to track the `openehr` gem dependency dropping Ruby 3.2 support at EOL); CI matrix covers 3.3/3.4/4.0, local dev pinned via `.ruby-version` (currently 4.0.7)
- Rails 7.0+ and Rails 8.x supported (CI matrix: `gemfiles/rails_{7_2,8_0,8_1}.gemfile`; demo app runs on Rails 8.1)
- URI compatibility workaround implemented for Ruby 3.4
- `ostruct` is an explicit development dependency — it left Ruby's default gems as of 4.0, and a couple of specs use `OpenStruct` as a lightweight test double
- Guard setup available for TDD workflow
- RuboCop Rails linting configured
- SimpleCov for test coverage
- `openehr` gem dependency; see the gem's own README/CHANGELOG for OPT-parser and AQL-engine capabilities and known gaps before relying on either.

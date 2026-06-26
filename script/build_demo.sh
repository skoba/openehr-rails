#!/usr/bin/env bash
#
# build_demo.sh — openehr-rails のデモアプリをゼロから再現構築するスクリプト。
#
# openEHR Operational Template (.opt) を渡すと Rails リソース（model/migration/
# controller/views/locale/FHIR プロファイル）が生成される様子を、第三者が再現・
# 確認できるようにする。題材として BMI テンプレート（OBSERVATION/数値）→問題リスト
# テンプレート（EVALUATION/コード化テキスト+日時）を順に scaffold し、CRUD 画面・
# 管理UI(/openehr)・FHIR R5 facade まで一通り用意する。
#
# 使い方:
#   cd /path/to/openehr-rails
#   bash script/build_demo.sh
#   cd demo && bin/rails server
#
# 生成される demo/ は再現可能なため git では追跡しない（.gitignore 済み）。
# 詳しい解説は doc/DEMO_ja.md を参照。

set -euo pipefail

# リポジトリのルート（このスクリプトの 1 つ上）へ移動
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DEMO_DIR="$REPO_ROOT/demo"
ASSETS_DIR="$REPO_ROOT/demo_assets"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

# 1. 前提チェック ------------------------------------------------------------
log "前提環境を確認します"
command -v ruby   >/dev/null 2>&1 || die "ruby が見つかりません"
command -v bundle >/dev/null 2>&1 || die "bundler が見つかりません (gem install bundler)"
command -v rails  >/dev/null 2>&1 || die "rails が見つかりません (gem install rails)"
ruby -v
bundle -v
rails -v

# 既存 demo/ の扱い
if [ -d "$DEMO_DIR" ]; then
  if [ "${FORCE:-0}" = "1" ]; then
    warn "既存の demo/ を削除して作り直します (FORCE=1)"
    rm -rf "$DEMO_DIR"
  else
    read -r -p "demo/ が既に存在します。削除して作り直しますか? [y/N] " ans
    case "$ans" in
      [yY]*) rm -rf "$DEMO_DIR" ;;
      *) die "中止しました。再生成するには既存の demo/ を退避/削除してください" ;;
    esac
  fi
fi

# 2. rails new --------------------------------------------------------------
log "Rails アプリ (demo/) を新規作成します"
rails new demo \
  --database=sqlite3 \
  --skip-test \
  --skip-jbuilder \
  --skip-action-mailbox \
  --skip-action-cable \
  --skip-kamal \
  --skip-ci

# 3. gem を配線して bundle install -----------------------------------------
log "Gemfile に openehr-rails (path: '..') を追記します"
if ! grep -q 'gem "openehr-rails"' "$DEMO_DIR/Gemfile"; then
  printf '\n# openEHR archetype/template scaffolding (local path)\ngem "openehr-rails", path: ".."\n' >> "$DEMO_DIR/Gemfile"
fi

cd "$DEMO_DIR"
log "bundle install"
bundle install

# 4. openehr:install --------------------------------------------------------
log "openehr:install（テンプレート登録モデル・RM テーブル・管理エンジン）"
bin/rails generate openehr:install
bin/rails db:migrate

# 5. BMI テンプレートを scaffold（OBSERVATION / 数値）------------------------
log "BMI テンプレートを scaffold (--fhir)"
bin/rails generate openehr:scaffold "$ASSETS_DIR/templates/bmi_calculation.opt" --fhir
bin/rails db:migrate
bin/rails db:seed

# 6. 問題リストを scaffold（EVALUATION / コード化テキスト+日時：2 リソース共存）
log "問題リスト(ProblemList) テンプレートを scaffold (--fhir)"
bin/rails generate openehr:scaffold "$ASSETS_DIR/templates/problem_list.opt" --fhir
bin/rails db:migrate
bin/rails db:seed

# 7. デモ用サンプルデータを投入 --------------------------------------------
log "サンプルレコードを投入します (demo_assets/demo_seed.rb)"
bin/rails runner "$ASSETS_DIR/demo_seed.rb"

# 生成されたルートを表示（実際のパス名はここを正とする）---------------------
log "生成されたルート"
bin/rails routes | grep -E 'bmi|problemlist|openehr' || true

# 8. 完了メッセージ ---------------------------------------------------------
cat <<'MSG'

============================================================
 デモアプリの構築が完了しました。
------------------------------------------------------------
 サーバ起動:
   cd demo && bin/rails server

 確認 URL (http://localhost:3000):
   CRUD   : /bmi_calculations , /problemlists
   管理UI : /openehr
   FHIR   : /openehr/fhir/metadata

 マニュアル: doc/DEMO_ja.md
============================================================
MSG

# openEHR テンプレートから Rails アプリを作るデモ（手順書）

このドキュメントは、`openehr-rails` gem を使って **openEHR Operational
Template (.opt) から Rails のリソース（model / migration / controller /
views / i18n / FHIR プロファイル）を自動生成し、動くアプリとして提示する**
までの手順をまとめたものです。

題材として、型の異なる 2 つのテンプレートを順に scaffold します。

| テンプレート | openEHR エントリ種別 | 主なデータ型 | 生成リソース |
|---|---|---|---|
| BMI 計算 (`bmi_calculation`) | OBSERVATION | DV_QUANTITY（数値＋単位）/ DV_TEXT | `/bmi_calculations` |
| 問題リスト (`ProblemList`) | EVALUATION | DV_CODED_TEXT（コード化）/ DV_DATE_TIME | `/problemlists` |

これにより「数値中心のテンプレート」と「コード化テキスト＋日時のテンプレート」が
同一アプリ内で共存し、CRUD 画面・管理 UI・FHIR R5 facade が動く様子を確認できます。

> ℹ️ 当初は血圧テンプレートを題材に予定していましたが、同梱の簡易サンプル
> (`spec/templates/sample_blood_pressure.opt`) は標準 OPT フォーマットでは
> なく、また CKM 由来の実際の血圧 OPT は `DV_DURATION` 等を含み現行 openehr
> gem の OPT パーサが未対応のため、本デモでは BMI と問題リストを採用しています。

---

## 1. 概要 — このデモで分かること

- `.opt` ファイルを 1 つ渡すだけで、Rails の標準的な CRUD 一式が生成される。
- 生成モデルは **型付きカラム**（フォーム/検索用）に加え、保存時に
  **openEHR 準拠の RM Composition** を `rm_composition`（JSON）と
  `openehr_rm_*` テーブル（型付きノードグラフ）へ永続化する。
- 各カラムは `FIELD_MAP` で openEHR の RM パス・データ型と結び付いている。
- 管理 UI (`/openehr`) から OPT をアップロードして実行時生成できる。
- 同じデータを **HL7 FHIR R5** の Observation として読み書きできる。

---

## 2. 前提環境

- Ruby 3.4 系（動作確認: 3.4.4）
- Bundler / Rails 8 系（`gem install rails`）
- SQLite3
- `openehr-rails` のソース一式（このリポジトリ）

確認:

```sh
ruby -v      # ruby 3.4.x
bundle -v
rails -v     # Rails 8.x
```

---

## 3. クイックスタート（再現スクリプト）

リポジトリのルートで再現スクリプトを実行すると、`demo/` に Rails アプリを
ゼロから構築し、2 テンプレートの scaffold・マイグレーション・サンプルデータ投入
までを一括で行います。

```sh
cd /path/to/openehr-rails
bash script/build_demo.sh        # demo/ が既にある場合は確認の上で作り直し
# 確認なしで作り直すなら: FORCE=1 bash script/build_demo.sh

cd demo
bin/rails server
```

ブラウザで以下を開きます（既定ポート 3000）。

| URL | 内容 |
|---|---|
| <http://localhost:3000/> | 管理 UI（登録テンプレート一覧 = ルート） |
| <http://localhost:3000/bmi_calculations> | BMI の CRUD 画面 |
| <http://localhost:3000/problemlists> | 問題リストの CRUD 画面 |
| <http://localhost:3000/openehr> | 管理 UI（テンプレート管理 / 実行時生成） |
| <http://localhost:3000/openehr/fhir/metadata> | FHIR CapabilityStatement |

`demo/` は再現可能なため git では追跡しません（`.gitignore` に登録済み）。
作り直したいときは `demo/` を消して再実行すれば、毎回同じ結果になります。

---

## 4. 手動手順（スクリプトの中身を 1 ステップずつ）

`script/build_demo.sh` が行っていることを手で再現する場合の手順です。

### 4.1 Rails アプリを新規作成し gem を配線

```sh
rails new demo --database=sqlite3 --skip-test --skip-jbuilder \
  --skip-action-mailbox --skip-action-cable --skip-kamal --skip-ci
cd demo
echo 'gem "openehr-rails", path: ".."' >> Gemfile   # ローカルパス参照
bundle install
```

### 4.2 初期セットアップ（openehr:install）

テンプレート登録モデル・RM 永続化テーブル・管理エンジン (`/openehr`) を導入します。

```sh
bin/rails generate openehr:install
bin/rails db:migrate
```

### 4.3 BMI テンプレートを scaffold（`--fhir` 付き）

```sh
bin/rails generate openehr:scaffold ../demo_assets/templates/bmi_calculation.opt --fhir
bin/rails db:migrate
bin/rails db:seed     # テンプレートを openehr_templates へ登録
```

期待される生成物（抜粋）:

```
Generating scaffold for template: bmi_calculation
Model name: BmiCalculation
      create  app/models/bmi_calculation.rb
      create  db/migrate/XXXXXXXXXXXXXX_create_bmi_calculations.rb
      create  app/controllers/bmi_calculations_controller.rb
      create  app/views/bmi_calculations/{index,show,new,edit,_form}.html.erb
      create  config/locales/bmi_calculation.en.yml
       route  resources :bmi_calculations
      create  app/fhir/profiles/openehr-observation-height-v2.json
      create  app/fhir/profiles/openehr-observation-body-weight-v2.json
      create  app/fhir/profiles/openehr-observation-body-mass-index-v2.json
```

### 4.4 問題リストテンプレートを scaffold（2 つ目のリソース）

```sh
bin/rails generate openehr:scaffold ../demo_assets/templates/problem_list.opt --fhir
bin/rails db:migrate
bin/rails db:seed
```

`Model name: Problemlist` / `route resources :problemlists` /
`app/fhir/profiles/openehr-evaluation-problem-diagnosis-v1.json` が生成されます。

### 4.5 デモ用サンプルデータの投入

```sh
bin/rails runner ../demo_assets/demo_seed.rb
# => [demo_seed] BmiCalculation: 3 records
#    [demo_seed] Problemlist: 3 records
```

---

## 5. 生成物の解説

### 5.1 モデル（`app/models/bmi_calculation.rb`）

```ruby
class BmiCalculation < ApplicationRecord
  include OpenehrRails::Storable      # 保存時に RM Composition を生成・永続化
  include OpenehrRails::AqlQueryable  # RM パスでの検索

  TEMPLATE_ID = 'bmi_calculation'
  ROOT_ARCHETYPE_ID = 'openEHR-EHR-COMPOSITION.report-result.v1'

  # カラム ⇔ openEHR RM パス / データ型 の唯一の対応表
  FIELD_MAP = {
    'height' => { label: "身長", path: ".../items[at0004]/value",
                  rm_type: "DV_QUANTITY", column_type: :float, units: "cm", ... },
    'body_weight'     => { ..., rm_type: "DV_QUANTITY", units: "kg" },
    'body_mass_index' => { ..., rm_type: "DV_QUANTITY", units: "kg/m2" },
    'body_mass_index_at0013' => { label: "判定", rm_type: "DV_TEXT", column_type: :string },
  }.freeze

  validates :height, numericality: { ... }, allow_nil: true
  # ...
end
```

- `FIELD_MAP` が「型付きカラム」と「openEHR RM パス・データ型」を結ぶ唯一の対応表です。
- `Model.find_by_path(rm_path, value)` で RM パス検索ができます（`AqlQueryable`）。

### 5.2 マイグレーション（型付きカラム＋RM 保存列）

```ruby
create_table :bmi_calculations do |t|
  t.float  :height
  t.string :height_units, default: 'cm'          # DV_QUANTITY は値＋単位列
  t.float  :body_weight
  t.string :body_weight_units, default: 'kg'
  t.float  :body_mass_index
  t.string :body_mass_index_units, default: 'kg/m2'
  t.string :body_mass_index_at0013               # DV_TEXT
  t.string :ehr_id
  t.datetime :composed_at
  t.json   :rm_composition                        # 正準 RM Composition (JSON)
  t.string :template_id, null: false, default: 'bmi_calculation'
  t.string :uid
  t.timestamps
end
```

### 5.3 フォーム — データ型に応じた入力欄

`_form.html.erb` は openEHR のデータ型に応じて入力 UI を出し分けます。

| openEHR 型 | 生成される入力 |
|---|---|
| DV_QUANTITY | `number_field`（min/max/step、単位ラベル付き）例: `身長 [____] cm` |
| DV_TEXT | `text_field` |
| DV_DATE_TIME | `datetime_field` |
| DV_CODED_TEXT（コード制約あり） | `select`（例: `[["Suspected","at0074"], ["Confirmed","at0076"]]`） |

> ⚠️ 既知の制約: 問題名 (`problem_diagnosis_problem_diagnosis_name`) のように
> **コード一覧の制約を持たない DV_CODED_TEXT** は、フォームでは選択肢が空の
> `select` として生成されます。値の保存・表示自体は可能です（`demo_seed.rb`
> では自由文字列を投入しています）。

### 5.4 i18n ロケール（OPT の用語定義から生成）

```yaml
en:
  activerecord:
    attributes:
      bmi_calculation:
        height: "身長"
        body_weight: "体重"
        body_mass_index: "Body mass index"
        body_mass_index_at0013: "判定"
```

### 5.5 openEHR としての保存（RM Composition）

レコードを保存すると、`FIELD_MAP` を通じて 1 件の COMPOSITION に変換され、
`rm_composition` 列（JSON）と `openehr_rm_*` テーブルに永続化されます。

```sh
bin/rails runner 'r=BmiCalculation.first; puts r.rm_composition.keys.inspect'
# => ["_type", "archetype_node_id", "archetype_details", "content", "uid"]
```

---

## 6. CRUD 画面の確認

- <http://localhost:3000/bmi_calculations> — 一覧（seed の 3 件: BMI 22.5 / 19.2 / 29.3）。
  「New」から数値を入力して新規作成、編集・削除も可能。
- <http://localhost:3000/problemlists> — 問題リスト（Hypertension / Type 2
  diabetes mellitus / Suspected asthma）。診断確実性は Suspected / Confirmed の
  プルダウン。

> 📷 マニュアル掲載時はここに一覧・新規フォームのスクリーンショットを挿入してください。

---

## 7. 管理 UI（`/openehr`）

<http://localhost:3000/openehr> はテンプレート管理エンジンです。

- 登録済みテンプレート（`bmi_calculation` / `ProblemList`）の一覧表示。
- OPT ファイルをドラッグ＆ドロップでアップロード。
- 「Generate UI」ボタンで、**実行中のアプリ内**で scaffold ジェネレータを起動
  （ファイル生成 → マイグレーション → ルート再読込）。サーバを再起動せずに
  新しいリソースが使えるようになります。

> 実行時生成はアプリにファイルを書き込むため、開発環境でのみ有効です。
> `config/initializers/openehr.rb` の
> `OpenehrRails.enable_runtime_scaffolding` で切り替えられます。

---

## 8. HL7 FHIR R5 facade の確認

エンジンは `<mount>/fhir`（既定 `/openehr/fhir`）に FHIR R5 API を提供します。
openEHR の OBSERVATION エントリ（BMI の各項目）が FHIR Observation として
公開されます。

### 8.1 CapabilityStatement

```sh
curl -s http://localhost:3000/openehr/fhir/metadata | head
# {"resourceType":"CapabilityStatement","status":"active",...,"fhirVersion":"5.0.0",...}
```

### 8.2 StructureDefinition（生成プロファイル）

```sh
curl -s http://localhost:3000/openehr/fhir/StructureDefinition/openehr-observation-height-v2
```

### 8.3 Observation 検索

```sh
curl -s http://localhost:3000/openehr/fhir/Observation
# {"resourceType":"Bundle","type":"searchset","total":12,
#  "entry":[{"resource":{"resourceType":"Observation",...,
#    "valueQuantity":{"value":170.0,"unit":"cm",...}}}, ...]}

# アーキタイプ（code）で絞り込み
curl -s "http://localhost:3000/openehr/fhir/Observation?code=openEHR-EHR-OBSERVATION.height.v2"
```

### 8.4 Observation 作成（FHIR-in / openEHR-stored）

FHIR の Observation を POST すると、モデルの `FIELD_MAP` を通じて openEHR の
RM Composition として保存されます。**単一項目のアーキタイプ**（例: 身長）で
確認するのが分かりやすいです。

```sh
curl -s -X POST -H 'Content-Type: application/fhir+json' \
  http://localhost:3000/openehr/fhir/Observation \
  -d '{
    "resourceType":"Observation","status":"final",
    "code":{"coding":[{"system":"http://openehr.org/ckm/archetypes",
                       "code":"openEHR-EHR-OBSERVATION.height.v2"}]},
    "valueQuantity":{"value":172.5,"unit":"cm",
                     "system":"http://unitsofmeasure.org","code":"cm"}
  }'
# => HTTP 201, 作成された Observation(JSON) が返る

# 保存を確認
bin/rails runner 'r=BmiCalculation.where.not(height: nil).last; \
  puts "height=#{r.height} rm=#{r.rm_composition.keys.inspect}"'
# => height=172.5 rm=["_type","archetype_node_id","archetype_details","content","uid"]
```

> ⚠️ 既知の制約: `body_mass_index` のように **複数項目を持つアーキタイプ**へ
> POST する場合は FHIR `component[]` 形式が必要です。`valueQuantity` 単体で
> POST するとレコードは作られますが型カラムには値が入りません。デモでは
> 単一項目の身長 (`height.v2`) を使った例を推奨します。

---

## 9. 2 リソースの共存

BMI（OBSERVATION / 数値）と問題リスト（EVALUATION / コード化テキスト＋日時）が
同一アプリで動作します。`bin/rails routes | grep -E 'bmi|problemlist|openehr'`
で両リソースと管理エンジン・FHIR ルートが確認できます。

---

## 10. クリーンアップ / 再生成

```sh
# demo アプリを破棄して作り直す（毎回同じ結果になる）
rm -rf demo
FORCE=1 bash script/build_demo.sh
```

---

## 付録: ファイル構成（このリポジトリ側）

```
script/build_demo.sh          再現スクリプト（本手順を自動化）
demo_assets/
  templates/bmi_calculation.opt   題材 OPT（BMI / OBSERVATION）
  templates/problem_list.opt      題材 OPT（問題リスト / EVALUATION）
  demo_seed.rb                    デモ用サンプルデータ投入スクリプト
demo/                          スクリプトが生成する Rails アプリ（git 非追跡）
doc/DEMO_ja.md                本書
```

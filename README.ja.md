[English](README.md) | 日本語

> 英語版の訳です。食い違うときは、英語版が正です。

[![CI](https://github.com/skoba/openehr-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/skoba/openehr-rails/actions/workflows/ci.yml)

# 概要

openehr-rails は、openEHR の Operational Template(`.opt`)を、コマンド
1 つで動く Rails のリソースにします。モデル、マイグレーション、CRUD の画面、
i18n のロケール、HL7 FHIR R5 のプロファイルを作ります。ほかと違うのは、
使いやすさと openEHR への適合を両立していることです。この 2 つはふつう
引き換えになりますが、ここでは両方が手に入ります。生成されたモデルは、ふつうの
ActiveRecord のモデルと同じように振る舞います(型付きのカラム、なじみのある
フォームと検索)。それでいて、保存のたびに、openEHR に完全に適合した RM の
Composition も保存します。canonical JSON と、版を持ち監査の記録が残るノードの
グラフです。対応付けのコードを手で書く必要はありません。HL7 FHIR R5 への対応は、
リソースごとに手で書くのではなく、同じ RM の型の対応から自動で導きます。
AQL(openEHR の問い合わせ言語)は、Ruby のモデルの API(`Model.aql`)、REST の
エンドポイント、ブラウザのコンソールのどれからでも、同じように動きます。

## 必要なもの

* 現在の版は Rails 7.0 以降と Rails 8.x に対応しています
* Ruby 3.3 以降が必要です(Ruby 3.4 で試験しています)
* Linux 上の CRuby 3.4 で開発しています
* 以前の版は、より古い Ruby と Rails に対応していました(git の履歴を見てください)

## 使い方

openEHR の Operational Template(.opt)から、Rails のリソース一式(モデル、
マイグレーション、コントローラ、ビュー、ルート、i18n のロケール、リクエストの
spec)を生成します:

```sh
# 最初に 1 回だけ: テンプレートの登録のモデル + マイグレーション + initializer
bin/rails generate openehr:install
bin/rails db:migrate

# OPT のファイルから scaffold する
bin/rails generate openehr:scaffold path/to/your_template.opt
bin/rails db:migrate
bin/rails db:seed   # テンプレートを openehr_templates のテーブルに登録する
```

生成されたモデルは、Rails のフォームと検索のための型付きのカラムを持ち、
**すべての記録を canonical な openEHR RM の Composition として保存します**。
まず `openehr_rm_*` のテーブルに **型付きのノードのグラフ** として
(install のマイグレーションを実行していれば)、また後方互換と書き出しのために、
`rm_composition` のカラムに JSON の文書としても保存します。

モデルの定数 `FIELD_MAP` は、各カラムを、openEHR の RM のパスとデータの値の型に
結び付けます。`Model.find_by_path(rm_path, value)` は、RM のパスをカラムに
解決します(`OpenehrRails::AqlQueryable`)。パスが FIELD_MAP に無ければ、
検索は(使えるときは)RM のグラフに切り替わり、アーキタイプの任意の要素を
問い合わせられます(`OpenehrRails::Rm` の層)。

scaffold のフォームには、イベントの時刻の入力がありません。そのため、記録は
保存の時刻(`composed_at`)を、`HISTORY.origin` と `EVENT.time`、context の
`start_time` に書きます。context の setting は `OpenehrRails.default_setting` です
(initializer でほかの openehr の setting の符号を設定しなければ `238` other care。
その用語に無い符号は、起動のときにエラーになります)。openEHR の REST API
(`/openehr/v1`)で commit する composition は、`HISTORY.origin` と `EVENT.time` を、
context があるときはその `start_time` と `setting` も持つ必要があります。無いものは、
足りないパスを書いた 422 で断ります。REST と FHIR は、これらの日時と context を、
部分的な値も時刻帯も含めて、commit したとおりに返します。AQL の `SELECT` は、
正規化した時点(いちばん早い時点、UTC)を返します。

生成される日付と時刻のカラムの、既知の制約:

* カラムが落とすか変えてしまう値は、その値を書いた検証のエラーで断ります。
  `datetime` のカラムでは年、年月、時までの値、`date` のカラムでは年と年月、
  `time` のカラムでは時までの値です。
* `datetime` のカラムに、時刻の無い日付(`2026-11-05`)を入れると、真夜中として
  保存されます。記録に無い時刻が足されます。記録した精度を保つには、実行時の経路
  (`/openehr/v1`)で commit してください。

オプション:

* `--namespace=ehr` は、コントローラ、ビュー、ルートに名前空間を付けます。
* `--fhir` は、HL7 FHIR R5 の StructureDefinition のプロファイル(OPT の
  エントリごとに 1 つ)も `app/fhir/profiles/` に書きます。プロファイルだけを
  `bin/rails generate openehr:fhir_profile <opt>` で生成することもできます。

### テンプレートの管理 UI

`openehr:install` は、管理のエンジンを `/openehr` にマウントします。登録された
テンプレートを一覧にし、OPT のファイルをドラッグ&ドロップのアップロードで
受け付けます。**Generate UI** のボタンは、動いているアプリの中で scaffold の
generator を実行します(ファイルの生成、マイグレーション、ルートの読み直し)。
そのため、サーバを再起動しなくても、新しいリソースをすぐに使えます。

実行時の scaffold はアプリにファイルを書くので、development の環境でだけ
有効です。次のように上書きできます:

```ruby
# config/initializers/openehr.rb
OpenehrRails.enable_runtime_scaffolding = true # または false
```

### 認証

エンジンが出すものはどれも、診療のデータを扱います。テンプレートの管理 UI、
AQL のコンソール、患者のタイムライン、openEHR の REST API(`/openehr/v1`)、
FHIR の facade(`/openehr/fhir`)です。そのため、`development` と `test` の
環境の外では、エンジンは **既定で閉じています**。認証のフックを設定するまで、
すべてのリクエストに `403 Forbidden` を返します。

フックは、リクエストを受けたエンジンのコントローラの中で `before_action` として
動きます(`instance_exec` で呼ぶので、`request`、`render`、`redirect_to` と、
アプリが `ActionController::Base` に混ぜ込んだヘルパーを使えます)。拒否するときは、
render か redirect をしてください。例外を投げるフックは、エンジンのコントローラの
一部にある `rescue_from StandardError` に捕まり、紛らわしいエラーとして
報告されることがあります。

```ruby
# config/initializers/openehr.rb

# Devise:
OpenehrRails.authenticate_with = -> { authenticate_user! }

# Bearer トークン:
OpenehrRails.authenticate_with = lambda do
  authenticate_or_request_with_http_token do |token, _options|
    ActiveSupport::SecurityUtils.secure_compare(
      token, Rails.application.credentials.openehr_api_token.to_s
    )
  end
end
```

入り口ごとに別の仕組みを使うには、`openehr_access_scope` で分けます
(`:admin` — テンプレートの UI、AQL のコンソール、タイムライン、`:rest_api` —
`/v1`、`:fhir` — FHIR の facade):

```ruby
OpenehrRails.authenticate_with = lambda do
  case openehr_access_scope
  when :admin then authenticate_user!
  else authenticate_or_request_with_http_token { |t, _| valid_api_token?(t) }
  end
end
```

意図して認証なしで動かすには(たとえば、認証を済ませるリバースプロキシの
後ろや、ネットワークから切り離した内部のアプリ):

```ruby
OpenehrRails.allow_unauthenticated_access = true
```

注意: JSON の API のコントローラ(`/v1`、`/fhir`)は CSRF の保護を外しています。
そのため、これらには、セッションの cookie よりもトークンによる認証を使ってください。

### HL7 FHIR R5 の facade

エンジンは、`<mount>/fhir`(既定は `/openehr/fhir`)に FHIR R5 の API も出します。
中身は scaffold したモデルです:

* `GET /openehr/fhir/metadata` — 登録されたアーキタイプのプロファイルを
  すべて並べた CapabilityStatement
* `GET /openehr/fhir/StructureDefinition/:id` — 生成されたプロファイル
* `GET /openehr/fhir/Observation?code=<archetype_id>&subject=<ref>` —
  searchset の Bundle
* `GET /openehr/fhir/Observation/:id` — read
* `GET /openehr/fhir/Condition?category=<archetype_id>&subject=<ref>` と
  `GET /openehr/fhir/Condition/:id` — Condition に対応付けたエントリ
  (`openEHR-EHR-EVALUATION.problem_diagnosis.v1`)。read と search だけです。
  アーキタイプの coding は `Condition.category` にあります(`Condition.code` は
  診断)。そのため、絞り込むパラメータは `category` です
* `POST /openehr/fhir/Observation` — create。FHIR のリソースは、モデルの
  FIELD_MAP を通して変換され、openEHR の RM の Composition として canonical に
  保存されます(`rm_composition` のカラム)。エラーは OperationOutcome で
  返します。

対応付けは、openEHR の RM の型から自動で導きます
(OBSERVATION→Observation、DV_QUANTITY→Quantity、
DV_CODED_TEXT→CodeableConcept、…。`OpenehrRails::Fhir::TypeMap` を
見てください)。エントリは、そのプロファイルが表すリソースとして出します。
Observation のエントリは Observation として、`TypeMap::ENTRY_ELEMENT_MAPS` に
行があるエントリはそのリソースとして(いまは problem_diagnosis →
Condition)出し、ほかのエントリ(INSTRUCTION、ACTION、…)は出しません。

Observation の日付と時刻の値は、下の Condition の dateTime の決まりに従います。
DV_DATE は、日付を入れた `valueDateTime` として出します(R5 の
`Observation.value[x]` に `date` はありません)。DV_TIME は `valueTime` の
`hh:mm:ss` として出します。記録にある時刻帯は外し(FHIR の time は時刻帯を
持てません)、時までの値は出しません。

#### Condition: facade が付ける値と、既知の制約

* `Condition.clinicalStatus` は FHIR R5 で必須ですが、problem_diagnosis の
  アーキタイプは臨床の状態を記録しません。facade がこの値を付けます。記録に
  ある値ではありません(system は
  `http://terminology.hl7.org/CodeSystem/condition-clinical`):
  * 記録に解決の日時(at0030)が無ければ `unknown`。null flavor として使います。
    記録には書いてない、という意味です;
  * あれば `inactive`。`abatementDateTime` と一緒に出します。at0030 は
    「解決または寛解」を表し、どちらかは言いません。そのため facade は
    `resolved` とは書きません。`inactive` は両方を含み、con-3 を満たします。

  生成されたプロファイルは、`clinicalStatus` にこのことを注記します
  (binding や固定の値は足しません)。
* `verificationStatus` には、アーキタイプのローカルの at-code(たとえば
  `at0076`)が入ります。これは R5 の `condition-ver-status` への required binding を
  満たしません。変換は ConceptMap の役目です。
* at0003(臨床的に認識された日時)→ `recordedDate` は近似です。プロファイルは、
  そのことを `ElementDefinition.comment` に書いています。
* 日時の葉(`onsetDateTime`、`recordedDate`、`abatementDateTime`)は、FHIR の
  dateTime として正しければ、記録のとおりに出します。時刻があってオフセットが
  無い値は UTC として読み(`Observation.effectiveDateTime` と同じ)、無い秒は
  補います。時までの値は、FHIR に書く形が無いので、日付までを出します。

#### 実行時に登録したテンプレート

scaffold したモデルが持たない記録 — openEHR の REST API(`/openehr/v1`)か
`OpenehrRails::Rm::CompositionCommitter` を通して RM のグラフに commit した
Composition — も、同じエンドポイントで、RM のグラフから直接読んで出します。
そのテンプレートは、既定では gem の `OpenehrTemplate` の登録から取ります。
テンプレートをほかの場所に持つホストのアプリは、呼び出せるもの 1 つで
テンプレートを渡します。テンプレートの id ごとに 1 つの
`{ template_id:, opt: }`(OPT の XML)を返すものです:

```ruby
# config/initializers/openehr.rb
Rails.application.config.to_prepare do
  OpenehrRails::Fhir.template_source = lambda do
    Template.where(status: 'active').map { |t| { template_id: t.template_id, opt: t.source_xml } }
  end
end
```

* いまの記録を読むときに使う版を返してください。同じテンプレートの id を
  2 回返すと `OpenehrRails::Fhir::TemplateSourceError`(500)になります。
* scaffold したモデルを持つテンプレートは、モデルからだけ出します。
* 実行時の記録の id は `c<composition の uuid の 16 進>-<エントリの番号>` です。
  uid が UUID でない Composition は出しません。実行時のテンプレートにしか無い
  アーキタイプへの `POST` は 422 を返します(作る先のモデルがありません)。
* 実行時の記録のコード化された値は、記録にある文字を `display` に、記録の
  用語体系を `system` に入れます。

### 新しいアプリをゼロから始める

[`templates/openehr_template.rb`](templates/openehr_template.rb) は、Rails の
アプリケーションテンプレートです。新しいアプリに、コマンド 1 つで openehr-rails を
組み込みます(`openehr:install` とマイグレーションまで):

```sh
rails new myehr -m https://raw.githubusercontent.com/skoba/openehr-rails/master/templates/openehr_template.rb
```

`OPENEHR_SAMPLES=1` を設定すると、このリポジトリのデモで使っている 3 つの
サンプルのテンプレート(BMI、プロブレムリスト、血圧)も scaffold します。テンプレートは
`OpenehrRails::Opt::RemoteFetcher` で HTTP から取ってきます。オプションの
すべては、ファイルの先頭の注釈を見てください。

[`script/build_starter.sh`](script/build_starter.sh) は、同じテンプレートを包んで、
独立したリポジトリ(専用の README と CI のワークフロー付き)を作ります。GitHub に
push して
[テンプレートリポジトリ](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository)
にするのに向いています。

### デモのアプリ(OPT → Rails のアプリ)

`script/build_demo.sh` は、この gem を使って、デモの Rails のアプリをゼロから
作ります。`demo/` を作り、3 つのテンプレート(BMI、プロブレムリスト、血圧)を FHIR の
プロファイル付きで scaffold し、サンプルのデータ(`demo_assets/demo_seed.rb`)を
入れます。1 回の実行で済みます。

```sh
bash script/build_demo.sh            # FORCE=1 で、既にある demo/ を作り直す
cd demo && bin/rails server          # http://localhost:3000
```

手順の詳細、生成されるもの、管理 UI、FHIR R5 の facade の確かめ方は、手順書
[doc/DEMO_ja.md](doc/DEMO_ja.md)(英語: [doc/DEMO.md](doc/DEMO.md))を
見てください。`demo/` はいつでも作り直せるので、git では管理していません。

## ライセンス
この製品は Apache 2.0 ライセンスの下にあります

 Copyright 2012-2026 Shinji Kobayashi, openEHR.jp

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

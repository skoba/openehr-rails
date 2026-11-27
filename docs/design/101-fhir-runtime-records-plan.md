# #101 実行時に登録したテンプレートの記録を、FHIR の入口から読む(計画。ゲート待ち)

Issue: skoba/openehr-rails#101。裁定: R-20261127-11(計画まで。実装には進まない)。
基準点: openehr-rails master `2e68b49`。読み取り越境: anlage main `ae6eb5e`(`docs/design/fhir-read-plan.md`、
`app/models/openehr_template.rb`、`app/lib/opt/rm_composition_committer.rb`、`db/schema.rb`)。

## 1. いまの状態(実測)

FHIR の入口(`/openehr/fhir`、`FhirController`)の段ごとの前提:

| 段 | コード | 前提 |
|---|---|---|
| どのリソースがあるか | `Fhir::ResourceRegistry.entries`(`discover_from_templates`・`entries_for`) | gem の `OpenehrTemplate.operational` から model 名を作り、その model の定数 `FIELD_MAP` |
| 記録を集める | `FhirController#scoped_records`(`entry.model.all`、`where(ehr_id:)`) | scaffold した model の表(1 記録 = 1 行) |
| 記録をリソースにする | `Fhir::Serializer.new(record).observations` | `record.public_send(field[:name])`、`record.id`・`ehr_id`・`composed_at` |
| 1 件を引く | `FhirController#resolve`(id = `<model の id>-<slug>`) | model の主キー |
| 作る | `FhirController#create`(`entry.model.create!`) | model |
| CapabilityStatement | `Fhir::CapabilityStatement.resource_components` | `ResourceRegistry.entries` |
| プロファイル | `Fhir::ProfileRepository`(`app/fhir/profiles` の JSON、無ければ `OpenehrTemplate.operational` から生成) | ファイルか `OpenehrTemplate` |

anlage(実行時の経路の実例)は:

- 記録を、gem の RM グラフに `Rm::CompositionCommitter.commit(..., ehr:, owner: nil)` で入れる。
  `openehr_rm_compositions` には `template_id`・`ehr_id`・`context_start_time` がある。scaffold の経路の記録も、
  同じ表に `owner`(model と id)つきで入る(`Rm::GraphPersister`)。**記録の置き場は、2 つの経路で同じ**
- テンプレートは自分の `templates` 表(`source_xml`、`template_id` と `version` で一意)に持つ。
  `OpenehrTemplate`(gem の `TemplateRegistry`)の表はあるが、書いていない。そのため `discover_from_templates` は 0 件
- 結果、どの段も anlage の記録に届かない

値を記録から取る処理は、gem に既にある: `Storable.attributes_from_rm_composition(canonical_hash)` が、
`FIELD_MAP` の `path` で canonical JSON をたどる。`FIELD_MAP` は `Opt::FieldExtractor` の出力と同じ形
(`lib/openehr_rails/storable.rb` の注釈)。つまり、**OPT と RM グラフの記録があれば、model が無くても値が取れる**。

あわせて見つけた、いまの不具合(この計画の外。別の Issue にする):

- `Fhir::Serializer` は、ENTRY の種類によらず、すべて `resourceType: 'Observation'` で組む。
  一方 `CapabilityStatement` は `TypeMap.resource_for_entry` で `Condition` などを名乗る。
  入口の routes は Observation だけ。EVALUATION の記録(例: problem_diagnosis)が Observation として出る

## 2. 案

### 案 A: ホストが、テンプレートと記録を渡す口(R-20261127-11 の 2)

- `ResourceRegistry.register_source(source)`。source は、entries(テンプレートの一覧)、記録の検索
  (entry と subject)、1 件の取得を答える
- 良い点: ホストが記録をどこに持っていても使える
- 弱い点: 口が広い(3 つ以上の操作)。記録から値を取る処理を、ホストが書く(anlage の `Opt::CompositionReader` の
  ように)。記録が gem の RM グラフにあるなら、gem が既に持つ処理の二重化になる

### 案 B: gem が RM グラフから直接読み、ホストが渡すのはテンプレートだけ(R-20261127-11 の 5 を絞った形)

- 記録: `Rm::Composition.latest.not_deleted.where(owner_type: nil)`(scaffold の model に属さない記録)。
  subject は `ehr.ehr_id`、時刻は `context_start_time`
- テンプレート: `template_id` から OPT を引く。既定は gem の `OpenehrTemplate.operational`。ホストは、
  テンプレートの置き場が別なら、引き方を 1 つ登録する:

  ```ruby
  # config/initializers/openehr_rails.rb(anlage の例)
  OpenehrRails::Fhir.template_source = lambda do
    Template.where(status: 'active').map { |t| { template_id: t.template_id, opt: t.source_xml } }
  end
  ```

- field の一覧: OPT から `Opt::FieldExtractor`(scaffold が `FIELD_MAP` を作るのと同じ処理)
- 値: `composition.to_canonical_hash` を field の `path` でたどる(`Storable.attributes_from_rm_composition` の
  たどり方を、model に依らない形に切り出して、2 つの経路で共有する)
- 良い点: ホストの口は 1 つ(テンプレートの一覧)。記録の読み方が gem に 1 つだけ。記録を RM グラフに置く
  ホストは、`OpenehrTemplate` を使っていれば、何も登録しなくても読める
- 弱い点: 記録が RM グラフに無いホストには効かない(その場合は案 A が要る。いまの利用者には無い)。
  RM グラフから読むので、scaffold の表の検索より遅い(記録ごとに canonical JSON を組む。AQL の
  `DatasetAdapter` と同じ程度)

### 推す案: 案 B

- 案 A の口が答えることのうち、記録の側は、RM グラフに既にある。ホストに渡させると、gem の処理の写しを
  ホストに求めることになる(anlage の計画が案 C を退けたのと同じ理由)
- 案 A は、RM グラフの外に記録を持つ利用者が現れたら、案 B の上に足せる(source の口を、テンプレートから
  記録へ広げる)。いまは作らない

## 3. 形(案 B)

### 3.1 Serializer を record に依らない形に分ける(R-20261127-11 の 1)

- `Fhir::ResourceBuilder.new(entry, values:, id:, subject_ehr_id:, effective_at:).build`。entry は field の一覧を持つ
  `ResourceRegistry::Entry`、values は field 名 → 値の Hash
- いまの `Fhir::Serializer.new(record)` は、record から values・id・`ehr_id`・`composed_at` を取って、
  `ResourceBuilder` を呼ぶだけにする。出すものは変えない(regression pin: いまの `serializer_spec.rb` を
  そのまま通す)
- 単位: いまは `#{name}_units` の属性を優先する。実行時の経路では、記録の DV_QUANTITY の `units` を values に入れる

### 3.2 entries と記録の出どころを 2 つにする(R-20261127-11 の 2・3)

- `ResourceRegistry::Entry` に `source`(`:model` か `:rm_graph`)と `template_id` を足す。`model` は `:rm_graph` で nil
- `ResourceRegistry.entries` = いまの model の entries + 実行時の entries(テンプレートのうち、同じ `template_id` の
  scaffold model が無いもの。scaffold の model があるテンプレートは、いまの経路で出す)
- 記録を集める・1 件を引く処理を、entry の出どころで分ける(controller の `scoped_records`・`resolve` を、
  `Fhir::RecordSource` の 2 つの実装に移す)
- CapabilityStatement・検索(`code`、`subject`)・1 件の取得・プロファイルは、どちらの経路の entry にも同じ入口で答える
- 実行時の entries のプロファイルは、`ProfileRepository.from_registry` と同じく、OPT から `ProfileGenerator` で作る
  (テンプレートの出どころを `template_source` にそろえる)
- id: FHIR の id は `[A-Za-z0-9\-\.]{1,64}`。composition の uid(`<uuid>::<system>::<n>`)は `:` を含むので使えない。
  案: `c<uuid の 32 桁の 16 進>-<ENTRY の順番>`(最長で 40 文字前後)。scaffold の経路の id(`<整数>-<slug>`)と
  先頭の文字で分けられる。版は id に入れない(いつも最新の版を返す)
- 作成(`POST /fhir/Observation`)は、実行時の entry では 422(作る先の model が無い)。実行時の作成は、この計画の外

### 3.3 Observation のほかの種類(R-20261127-11 の 4)

- 実行時の経路も、いまの経路と同じく、`TypeMap.assert_supported!` を通る entry だけを出す
  (Observation と、`ENTRY_ELEMENT_MAPS` に行のある ENTRY。いまは problem_diagnosis の Condition だけ)
- Condition を出すには、`ENTRY_ELEMENT_MAPS` の leaf を、Observation の value[x]/component ではなく、
  その要素(`code`、`onsetDateTime` など)に置く組み立てと、`/fhir/Condition` の routes が要る。
  1 節の不具合(EVALUATION を Observation で出す)と同じ所なので、それを直す別の Issue で、2 つの経路を一度に扱う
- この計画の段 1〜3 は Observation だけ。Condition は段 4(別 Issue の後)

## 4. 決めてほしいこと(ゲート)

1. 案 B(RM グラフから読み、ホストはテンプレートの一覧だけを渡す)でよいか。案 A(記録も渡す口)を先に作るか
2. 実行時の記録の範囲を `owner_type IS NULL` の記録にし、scaffold の model があるテンプレートは、いまの経路だけで
   出す(二重に出さない)でよいか
3. テンプレートの版: RM の composition には `template_id` しか無い(版を持たない)。`template_source` が同じ
   `template_id` の版を複数返したときは、どれを使うか。案: 最後に返したもの(ホストが「いまの版」を返す責任を持つ)
4. 1 節の不具合(EVALUATION を Observation で出す)を、別の Issue に起票してよいか(bug。直し方は Condition の
   組み立てと routes で、公開 API の追加を含む)

## 5. semver の見込み

- 段 1(Serializer の分割): patch 相当(挙動を変えない。内部の整理)。単独では公開しない
- 段 2・3(`template_source` と実行時の entries): minor(公開 API の追加。scaffold の経路は変えない)
- 段 4(Condition): minor(別 Issue)

## 6. 実装の段

1. `ResourceBuilder` を切り出す(refactor。いまの spec が green のまま)
2. RM グラフの記録から values を取る処理(`Storable` のたどり方を切り出して共有)と、`template_source`
3. `ResourceRegistry` の実行時の entries、`RecordSource` の 2 つの実装、controller の差し替え、CapabilityStatement
4. (別 Issue)Condition

## 7. Red から始める spec の見出し

- enhancement: RM グラフにある、model の無い記録が、`GET /fhir/Observation?code=<archetype_id>` に出る
- enhancement: `subject=Patient/<ehr_id>` で、その EHR の記録だけに絞れる
- enhancement: `GET /fhir/Observation/<id>` で、実行時の記録の 1 件が引ける。消した版(lifecycle 523)は 404
- enhancement: `template_source` を登録すると、`OpenehrTemplate` に無いテンプレートの entry が
  CapabilityStatement と `StructureDefinition` に出る
- enhancement: 実行時の entry への `POST /fhir/Observation` は 422
- regression pin: scaffold の model の記録は、いまと同じ id・同じ形で出る(`serializer_spec.rb` を変えずに通す)
- regression pin: scaffold の model があるテンプレートの記録は、二重に出ない
- regression pin: `ENTRY_ELEMENT_MAPS` に無い Observation 以外の ENTRY は出ない
- 入口の確かめ: engine の controller には request spec が無い。#94・#95・#99 と同じく、組み立てた demo に
  curl して確かめ、その結果を PR に書く。controller の判断は、spec のある class に置く

## 8. ゲートの回答と実装(R-20261127-15)

- 回答: 案 B。実行時の記録は owner の無い記録で、scaffold の model のあるテンプレートは今の経路だけ。
  `template_source` は template_id ごとに 1 つ。重なりは `TemplateSourceError`(template_id を書く)で止める。
  古い版のテンプレートで書いた記録の扱いは Known limitations に書く
- 実装: 段 1 は `Fhir::ResourceBuilder`(`Serializer` から切り出し。出力は変えない)。段 2・3 は
  `Fhir.template_source` と `Fhir::TemplateSource`、`ResourceRegistry.runtime_entries`、`Fhir::RuntimeRecord`、
  `Fhir::ObservationQuery`(検索・1 件・作成先の判定。controller はこれに渡すだけ)。値のたどり方は
  `Storable.value_node`・`attribute_value` に出して、2 つの経路で共有する
- 実装の細目(回答を実装するときに要った点):
  - `TemplateSourceError` は 500 で返す(ホストの設定の誤りで、要求の誤りではない)
  - entry の番号は、テンプレートの中の archetype ごとの並び(Observation 以外も数える)。Condition を足しても、
    今の id が変わらない
  - プロファイルの 1 件の取得は、`app/fhir/profiles` にファイルがあっても、無いテンプレートは生成したものから探す
    (いまは、ファイルが 1 つでもあると生成したものを見ない)
  - CapabilityStatement の `supportedProfile` は、同じ archetype を 1 回だけ書く(2 つのテンプレートが同じ
    archetype を使うと、2 回出ていた。demo で実測)
  - プロファイルの id は、OPT 自身の template_id から作る(`template_source` の `template_id` ではない)。
    ふつうは同じ

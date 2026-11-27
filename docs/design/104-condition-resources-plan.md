# #104 EVALUATION の記録が Observation として出る(計画)

Issue: skoba/openehr-rails#104(bug)。裁定: R-20261127-15 の 4(起票し、#101 の計画書 3.3 の形で計画書を足して、そのまま進む。
出るリソースの種類が変わるので Upgrade note)。基準点: openehr-rails master `e2fa3d6` と、#101 の PR #103(head `9aaf294`)。

## 1. いまの状態(実測)

- `Fhir::Serializer`(#103 からは `Fhir::ResourceBuilder`)は、ENTRY の種類によらず `resourceType: 'Observation'` で組む。
  scaffold した problem list(`openEHR-EHR-EVALUATION.problem_diagnosis.v1`)は `GET /fhir/Observation` に、
  leaf を `component[]` に並べた Observation として出る
- `Fhir::CapabilityStatement` は同じ entry を `type: 'Condition'` で載せる。`/fhir/Condition` の routes は無い。
  interaction に `create` も載る(作成は Observation だけ)
- 生成するプロファイルは Condition(`ProfileGenerator`、`TypeMap::ENTRY_ELEMENT_MAPS`)。出しているものは、それに合わない
- `ENTRY_ELEMENT_MAPS` に無い、Observation 以外の ENTRY(ACTION、INSTRUCTION など)も Observation として出ている。
  プロファイルの側は、それらを出さない(`TypeMap.assert_supported!`)

## 2. 直し方

### 2.1 何を、どのリソースとして出すか

- entry の扱いを、プロファイルと同じ判定にそろえる(`TypeMap.assert_supported!`):
  - Observation の entry: いまのまま
  - `ENTRY_ELEMENT_MAPS` に行のある entry: その行のリソース(いまは problem_diagnosis → Condition だけ)
  - どちらでもない entry: 出さない
- scaffold の経路と、#101 の実行時の経路の両方に効かせる(組み立ては `ResourceBuilder` の 1 か所)

### 2.2 Condition の組み立て(`multi-leaf-non-observation-plan.md` §8.1 の表のとおり)

| leaf | Condition の要素 | 値 |
|---|---|---|
| (archetype) | `category[]` | `{ coding: [{ system: <CKM>, code: <archetype_id> }] }`(プロファイルの `ckm` slice と同じ) |
| at0002 | `code` | CodeableConcept(DV_CODED_TEXT の code と terminology。DV_TEXT なら `text`) |
| at0077 | `onsetDateTime` | 記録の文字列 |
| at0003 | `recordedDate` | 記録の文字列 |
| at0030 | `abatementDateTime` | 記録の文字列 |
| at0073 | `verificationStatus` | CodeableConcept(local の at-code のまま。condition-ver-status への写しはしない。§8.2 と同じ) |

- 表に無い leaf(例: problem_list.opt の at0070)は出さない。`component` は使わない
- `subject` は Observation と同じ(`Patient/<ehr_id>`)。`effectiveDateTime` は Condition に無いので出さない
- 表示名(`display`): scaffold の経路は、いまと同じく `code_labels`(OPT の local の語)から。
  実行時の経路は、記録の DV_CODED_TEXT の `value`(例: ICD-11 の病名)を使う。記録にあるのに捨てない

### 2.3 入口

- `GET /fhir/Condition`(検索)、`GET /fhir/Condition/:id`(1 件)。id の形は Observation と同じ
  (scaffold の経路は `<record id>-<slug>`、実行時の経路は `c<uuid hex>-<entry index>`)
- `/fhir/Observation/:id` で Condition の id を引くと 404、その逆も 404(リソースの種類を確かめる)
- 作成(`POST /fhir/Condition`)は作らない。CapabilityStatement の interaction は、Observation が read・search-type・create、
  Condition が read・search-type
- 検索・1 件の判定は `Fhir::ObservationQuery`(#103)を、リソースの種類を受ける形(`Fhir::ResourceQuery`)に広げる。
  #103 はまだ公開していないので、名前は変えてよい

### 2.4 この計画で足した判断(裁定に無い。PR はマージせずにゲート報告にする)

- **Condition を archetype で絞る検索のパラメータ**。Observation の `code=<archetype_id>` は、FHIR の `Observation.code` に
  archetype の coding があるので、FHIR の意味どおり。Condition では archetype の coding は `category` にあり、
  `Condition.code` は病名(at0002)。案:
  - (a) `category=<archetype_id>`。FHIR の検索パラメータ `category`(`Condition.category`)の意味どおり。
    「archetype の coding がある要素で絞る」という、Observation と同じ規則になる。**推すのはこれ**
  - (b) `code=<archetype_id>`。この facade のいまの慣習(README の `code=<archetype_id>`)にそろう。
    ただし FHIR の `Condition.code`(病名)の検索と意味がぶつかる
- CapabilityStatement の `searchParam` は、種類ごとに実際に受けるものを書く(Observation: `code`・`subject`、
  Condition: `category`・`subject`)

## 3. semver

- minor。出るリソースの種類が変わる(EVALUATION の記録が Observation の検索から消え、Condition として出る。
  対応の表に無い Observation 以外の entry は出なくなる)。入口の追加(`/fhir/Condition`)。Upgrade note を書く

## 4. Red から始める spec の見出し

- bug: scaffold した problem list の記録が `Observation` の検索に出ない(いまは出る)
- bug: 対応の表に無い Observation 以外の entry(例: INSTRUCTION)が出ない(いまは Observation として出る)
- enhancement: `Condition` の検索(`category`、`subject`)と 1 件の取得で、§2.2 の形の Condition が返る。scaffold と実行時の両方
- enhancement: 実行時の記録の Condition の `code.coding.display` は、記録の DV_CODED_TEXT の `value`
- enhancement: Observation の id を Condition で引くと nil(404)、その逆も
- enhancement: CapabilityStatement の Condition に `create` が無く、`searchParam` が `category`・`subject`
- regression pin: Observation の entry の出力は変わらない(`serializer_spec.rb` を変えずに通す)
- 入口の確かめ: demo に curl(problem list の scaffold の記録と、実行時の記録)

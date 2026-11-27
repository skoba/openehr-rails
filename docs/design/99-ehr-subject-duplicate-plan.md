# #99 同じ subject の 2 つめの EHR を作れる(計画。ゲート待ち)

Issue: skoba/openehr-rails#99。裁定: R-20261127-6「あわせて」(計画を出したところでゲート報告。実装には進まない)。
基準点: openehr-rails master `813634c`(#95 の PR #98 の前)。

## 1. いまの状態(実測)

- `POST /v1/ehr` と `PUT /v1/ehr/:ehr_id` は、既にある EHR と同じ `subject_id`・`subject_namespace` の EHR を作る。
  #95 のブランチから組んだ demo で、`PUT /v1/ehr/ehr-b` と `PUT /v1/ehr/ehr-c`(どちらも `p-200`/`hosp`)が、2 回とも 201 だった
- `openehr_ehrs` に `(subject_id, subject_namespace)` の一意の制約は無い(install の migration テンプレート)。
  `Rm::Ehr` の validation も `ehr_id` の一意だけ
- 生成モデル(`Storable`)の保存で作られる EHR は、subject を持たない(実測: `lib/openehr_rails/rm/graph_persister.rb` 59 行の
  `Ehr.find_or_create_by!(ehr_id: ehr_id)`)。この経路は今回の変更の外

## 2. 仕様(読んだもの。2026-11-27)

ITS-REST の EHR API(https://specifications.openehr.org/releases/ITS-REST/latest/ehr.html、STABLE):

- 「Create EHR」(`POST /ehr`)の 409: "Unable to create a new EHR due to a conflict with an already existing EHR with the same
  subject id, namespace pair, whenever EHR_STATUS is supplied." → **いまの実装は、これに反している(bug)**
- 「Create EHR with id」(`PUT /ehr/{ehr_id}`)の 409: "...Can happen when the supplied `ehr_id` is already used by an existing EHR."
  subject には触れていない
- EHR_STATUS を送らないとき、または subject に id が無いとき(匿名の `PARTY_SELF`)の扱いは書いていない

RM の EHR IM(https://specifications.openehr.org/releases/RM/latest/ehr.html、Release-1.1.0):

- 4.4.1: 患者ごとに 1 つの EHR id は理想で、"can only approximate it"
- 4.4.2: 分散した環境で、1 人に複数の EHR id があることを認めている
- 4.5: "a duplicate or additional record for a patient already having a primary EHR" を、EHR を不活性にする理由に挙げる
- 1 つのシステムで subject ごとに EHR を 1 つに限る規則は無い

## 3. 案

### 3.1 `POST /v1/ehr`(仕様が決めている)

- EHR_STATUS の subject に id と namespace が両方あり、同じ組の EHR が既にあれば、409 と `{ "error": ... }`。作らない
- subject に id が無い(匿名)ときは、これまでどおり作る(regression pin)
- 409 の本文に、既にある `ehr_id` を入れるか: #95 の 409 にそろえて `ehr_ids` を入れる案。
  ただし、作成の 409 で既存の EHR の id を返すのは、呼び手に別の患者の EHR の所在を教えることになる(アクセスの範囲は同じ `:rest_api` なので、
  #95 の GET で引けるものと同じ)。推すのは「入れる」(#95 とそろえる)

### 3.2 `PUT /v1/ehr/:ehr_id`(仕様が決めていない)

- (a) `POST` と同じく 409 にする。理由: 同じ subject の 2 つめを、入口によって作れたり作れなかったりさせない
- (b) いまのまま(仕様どおり `ehr_id` の重複だけを 409)
- 推すのは (a)。仕様に無い、この実装の扱いとして、変更履歴と spec の注釈に書く

### 3.3 一意の制約を DB に足すか

- (i) 足さない。controller(または `Rm::Ehr` の validation)で確かめる。migration は要らない。同時の 2 つの要求で、重複がすり抜ける余地が残る
- (ii) 足す。`add_index :openehr_ehrs, %i[subject_id subject_namespace], unique: true`(NULL は重複に数えない)。
  install のテンプレート(出荷物)と、既存の導入先の追加の migration が要る。既に重複がある導入先では、migration が失敗する
- 推すのは (i)。ホストのアプリに migration を求めないこと(R-20261126-14 の 1 と同じ優先)と、既存の重複で migration が止まることを避けるため。
  すり抜けの余地は、変更履歴に書く

### 3.4 既にある重複

- 作成の側を直しても、既にある重複は残る。#95 の GET は、それを 409 で知らせる(R-20261127-6 の 1)
- 重複を見つけて直す道具(rake タスクなど)は、この Issue に含めない

## 4. semver

- 3.1 は bug の修正だが、既定の挙動が変わる(これまで 201 だった要求が 409 になる)。3.2 の (a) も同じ。minor とみる。Upgrade note に書く

## 5. ゲートで決めてほしいこと

1. `PUT /v1/ehr/:ehr_id` も 409 にするか(推すのは (a) する)
2. DB の一意の制約を足すか(推すのは (i) 足さない)
3. 作成の 409 の本文に、既にある `ehr_id` を入れるか(推すのは入れる)

## 6. 実装に進むときの Red(ゲートの回答のあと)

- bug: 同じ subject で `POST` すると 409、EHR の数は増えない(いまは 201)
- (a) なら bug ではなく enhancement: 同じ subject で `PUT` すると 409
- regression pin: 匿名の EHR は何度でも作れる。`ehr_id` の重複の `PUT` は、これまでどおり 409

## 7. ゲートの回答と実装(R-20261127-8)

- 回答: 3 点とも推奨のとおり。PUT も 409、DB の制約は足さない(すり抜けは Known limitations に書く)、409 の本文に既にある `ehr_id` を入れる
- 実装: 判定は `OpenehrRails::Rm::EhrCreation`(spec はここに書く)。controller の `create`・`upsert` は、その結果を状態コードに写すだけ
- 実装の細目(挙動の方針は足していない):
  - 確かめる順は、`ehr_id` の重複(PUT)が先、subject の重複があと
  - `ehr_id` の重複の 409 の本文は、これまでどおり `{ "error": ... }` だけ(`ehr_ids` を足さない)
  - subject を比べるのは、id と namespace の両方があるときだけ(片方だけのときも、匿名と同じに扱う)
  - `ehr_ids` は古い順(`time_created`、同じなら `id`)。#95 の GET の 409 とそろえる
- Red: 3 つ(POST の重複 2 つ〔bug〕、PUT の重複 1 つ〔enhancement〕)。いまの挙動を class に移したところで落ちることを確かめてから直した

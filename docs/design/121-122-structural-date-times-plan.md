# #121・#122 構造の日時と、scaffold の日時のカラム(計画)

Issue: [#121](https://github.com/skoba/openehr-rails/issues/121)、[#122](https://github.com/skoba/openehr-rails/issues/122)。
裁定: R-20261128-2。状態: **案。実装の前にゲート**(#121 の案 B は migration を含む。#122 は生成するコードの挙動を変える)。

測ったもの: master `7efef0a`(0.14.1)、openehr 2.9.0、Rails 8.1.4.1、TZ=Asia/Tokyo。結果は Issue の本文にある。

方針(R-20261128-2 に引かれた、11/27 の方針): 日時は、記録したとおりに返す。分かっているところまでを表し、それより細かいところは作らない。

## 1. いまの姿(#121)

| 日時 | 持つ場所 | 書き戻し |
| --- | --- | --- |
| `EVENT_CONTEXT.start_time` | `openehr_rm_compositions.context_start_time`(datetime) | REST: **書かない**(`CanonicalSerializer#call` に `context` が無い)。AQL・FHIR: 時点を `iso8601` |
| `HISTORY.origin` | `openehr_rm_nodes.history_origin`(datetime) | `history_origin.iso8601`(UTC) |
| `EVENT.time` | `openehr_rm_nodes.event_time`(datetime) | `event_time.iso8601`(UTC) |

記録に無い値を作るところ(`RmObjectBuilder`):

| 属性 | 作る値 | 記録で働くか(実測) |
| --- | --- | --- |
| `EVENT.time` | `Time.current` | 働く。scaffold の記録は `EVENT.time` を持たないので、すべての記録で働く。AQL が、問い合わせた時刻を返す |
| `HISTORY.origin` | `context_start_time`、無ければ `Time.current` | `to_rm` で働く(AQL はまだ `origin` を選べない) |
| `EVENT_CONTEXT.setting` | `other` / `other` | 働く。`start_time` があって `setting` が無い記録。scaffold の記録は、いつもこれ(`setting` を書かない)。`other` は openehr の用語に無い |
| `INTERVAL_EVENT.width`・`math_function` | `PT0S`・`144` | 働かない。`IntervalEvent` の検証が、無い記録を断る |

## 2. #121 記録した文字をどこに持つか

### 案 A(推す): いまある `extra`(JSON)に持つ。migration なし

- `openehr_rm_nodes.extra` に `'origin_value'`、`'time_value'`、`openehr_rm_compositions.extra` に `'start_time_value'`。
  どちらの表にも `extra` の列は install のときからある(#69 が `action_archetype_id` に使った)
- 時点の列(並べ替え、AQL の比べる値)は今のまま。#109 の `PartialTemporal.instant` で読む(いちばん早い時点、時刻帯の無い値は UTC)
- 書き戻しは、記録した文字があればそれ、無ければ時点の `iso8601`(すでにある行)
- 得るもの: host アプリの手順が無い。install のひな形(出荷物)を変えない。#63 が列を足さずに `text_value` を使ったのと同じ考え
- 失うもの: 記録した文字を SQL で引けない(引く用途は今は無い。比べるのは時点の列)。列の名前が中身を表さない

### 案 B: 文字の列を足す。migration あり

- `context_start_time_value`、`history_origin_value`、`event_time_value`(string)
- install の migration ひな形に足す。すでにある host アプリには、追加の migration が要る。
  generator(`openehr:upgrade` のような)を足すか、Upgrade note に migration の本文を書く
- 列が無い host アプリでも動くように、読むときは `has_attribute?` で分ける(移行の途中の db)
- 得るもの: 名前が中身を表す。失うもの: host アプリの手順、出荷物の変更、generator を足すなら公開の面が増える

### すでにある行(両案で同じ)

- 記録した文字は、もう無い。時点の `iso8601` を返す(今と同じ)。作り直すことはできない。Upgrade note に書く

## 3. #121 読み出しの変更

- REST(`CanonicalSerializer`): `context` を書く。`start_time` は記録した文字、`setting` は記録したもの。
  - 決めること: `CanonicalSerializer` の約束(「`Storable#to_rm_composition` の出力と deep-equal」)が変わる。
    scaffold の記録は `context` を持たないが、`context_start_time`(`composed_at`)を持つので、`context` が増える。
    約束を「commit した hash と deep-equal(scaffold の記録には `context.start_time` が足される)」に書き直す
- FHIR: `effective[x]` は、context の記録した文字を `date_time_string` に通す(#110 の決まり)
- AQL: SELECT は、今のまま正規化した値(#106 の `normalize_date_times`)。記録した文字を返すのは #92 の仕事で、待ちのまま
- `to_rm`(正規化しないとき): 記録した文字で `DvDateTime` を作る

## 4. #121 記録に無い時刻を作らない

openEHR RM では `EVENT.time`、`HISTORY.origin`、`EVENT_CONTEXT.setting` は必須。いま、記録に無いときに作っている。案:

- 4.1 scaffold の記録(`Storable`): 記録そのものが時刻を持つ(`composed_at`。保存したときに入る)。
  `to_rm_composition` が、`HISTORY.origin` と `EVENT.time` に `composed_at` を書く。記録に書いた値になるので、作った値ではない。
  `context.setting` は、設定の既定(`OpenehrRails.default_setting`、既定は `238` other care)。言語・地域・作成者と同じ扱い
- 4.2 `/v1` の commit: 必須の属性が無い composition は、422 で断る(`EVENT.time`、`HISTORY.origin`、`context` があるときの `setting`)。
  案 4.2' は、断らずに `context.start_time` で埋める。推すのは 4.2(RM で必須。埋めると、記録に無い値になる)。
  これまで通っていた commit が断られるので、挙動の変更
- 4.3 すでにある行で、時刻が無いもの: `context_start_time` を使う(その記録の時刻)。それも無ければ、`EVENT.time` を AQL で `nil` にする。
  `to_rm` が `nil` を受けないときは、その行を AQL から外す(#90 の未対応の型と同じ扱い)。どちらになるかは、実装の Red で測る
- `setting` の `other` / `other` は、`238` / `other care` にする。すでにある行も、読むときにそうなる

## 5. #122 scaffold の型付きのカラム

Rails の型の変換が、部分的な値を `nil` にする、または時を落とす(`2026-11-05T09` → `00:00`、`09` → `09:00:00`)。検証は通る。

### 案 A(推す): 検証のエラーにする。gem の中で

- `Storable` が、`FIELD_MAP` の `DV_DATE`・`DV_DATE_TIME`・`DV_TIME` の項目について、`<name>_before_type_cast` を調べる。
  カラムが持てない形(`date` に年・年月、`datetime` に年・年月・時まで、`time` に時まで)なら、
  `errors.add(name, :partial_date_time, value:)`(「`2026-11` は、この項目に保存できない精度です」)
- 生成するコード(`lib/generators/**/templates/`)を変えない。すでに生成した model も、gem を上げると働く。作り直しは要らない
- 得るもの: 黙って消えない。手順が無い。失うもの: 部分的な値は、scaffold の model には保存できないまま(実行時の経路 `/openehr/v1` を使う)

### 案 B: 記録した文字も持つ

- 生成する migration に `<name>_value`(string)を足し、`Storable` が composition にそちらを書く
- すでに生成した model は、migration の追加と、作り直しが要る。form の入力の型も決め直す
- 得るもの: 部分的な値が scaffold でも保存できる。失うもの: 生成するコードと host アプリの手順が大きく変わる

### 案 C: 項目の型を文字にする(`attribute :x, :string`)

- 採らない。view・form・host アプリのコードが、`Date`・`Time` を受けているところが壊れる

## 6. 進め方と semver

- PR を 2 つ(1 Issue = 1 PR)。#122 の案 A は小さいので先。#121 はそのあと
- Red を先に書く。Issue に書いた測定を spec にする(REST・FHIR・AQL の 3 つの出口、部分的な値と時刻帯つきの値、時刻の無い記録)
- semver の見込み: **minor**。REST の応答に `context` が増え、日時が記録した文字で返り、`/v1` で断られる commit ができ、
  scaffold の model で検証のエラーが起きる。どれも不具合の修正だが、host アプリから見える挙動が変わる。
  案 B を採るなら、migration を足すので、Upgrade note の手順が要る(それでも minor)
- 変更履歴は、PR ごとの `changelog.d/` の断片

## 7. ゲートで決めてほしいこと

1. #121 の持ち場所: 案 A(`extra`、migration なし)か、案 B(列を足す、migration あり)か
2. #121 4.2: `/v1` で必須の日時が無い commit を、断るか(推す)、`context.start_time` で埋めるか
3. #121 4.1: scaffold の `setting` の既定を、`238` other care(設定で変えられる)にしてよいか
4. #121 3: `CanonicalSerializer` の約束を書き直して、scaffold の記録にも `context` を出してよいか
5. #122: 案 A(検証のエラー、gem の中)か、案 B(記録した文字も持つ)か

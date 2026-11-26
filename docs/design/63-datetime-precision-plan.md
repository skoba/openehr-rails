# #63 DV_DATE_TIME の部分精度とオフセットを保つ(計画。ゲート待ち)

Issue: skoba/openehr-rails#63(anlage の上流候補 21 項)。裁定: R-20261124-16 の作業列 6、R-20261126-3 の 4
(「計画を出したところでゲート報告」)。状態: **計画。ゲートの回答を待つ。実装には進まない**。

- 基準点: openehr-rails master `a5e9a15`、openehr 2.6.1(openehr-ruby#59 は 2.6.0 に入った。タグ `v2.6.0` が修正のコミット `83a1d18` を含む)
- 「実測」はこのリポジトリの作業ツリーで実行したもの。「推論」は根拠を添える

## 1. いまの状態(実測)

### 1.1 往復で値が変わる

jp_referral の `problem_diagnosis_at0077`(DV_DATE_TIME)に文字列を入れて保存し、グラフから読み戻した
(spec の環境。`Time.zone` は spec の設定のまま):

| 入れた値 | `rm_composition`(JSON 列) | グラフ → `CanonicalSerializer` | AQL の SELECT |
|---|---|---|---|
| `2026-03-01` | `2026-03-01` | `2026-02-28T15:00:00Z` | `2026-02-28T15:00:00Z` |
| `2026-03-01T10:00` | `2026-03-01T10:00` | `2026-03-01T01:00:00Z` | `2026-03-01T01:00:00Z` |
| `2026-03-01T10:00:00+09:00` | 同左 | `2026-03-01T01:00:00Z` | `2026-03-01T01:00:00Z` |

- 精度とオフセットが落ちるだけでなく、**日付だけの値は、ホストのタイムゾーンで 0 時と読まれて UTC に直され、日付が前日に変わる**。
  Issue の本文(「`2026-03-01T00:00:00Z` で返る」)より悪い
- 原因: `GraphBuilder#parse_time` が `Time.zone.parse` で `datetime_value`(datetime 列)に入れ、
  `DataValues::DvDateTime#to_canonical` と `RmObjectBuilder#dv_date_time` が `iso8601` で書き戻す
- `Storable` の生成モデルは DV_DATE_TIME を datetime 列で持つので、フォームからの保存では部分精度の値はふつう生じない(推論:
  列の型から)。部分精度の値が入るのは、canonical JSON の commit(REST、anlage の帳票)の経路

### 1.2 openehr 2.6.1 の `DvDateTime` の比較(上流)

- 部分精度の値は受け取れる(`2026-03-01`・`2026-03`・`2026`・`2026-03-01T10` が、そのまま `value` に残る。実測)
- 比較(`<=>`、`magnitude`)は、欠けた部分を最も早い値として扱う。`2026-03-01 <=> 2026-03-01T00:00:00Z` は 0(実測。上流の設計どおり)
- **正のオフセットの向きが逆**。`2026-03-01T10:00:00+09:00`(= 01:00Z)は、`09:00Z`・`10:00Z`・`11:00Z` のどれより後と判定される(実測)。
  `magnitude` が、`+hh:mm` のときに時と分を足している(`lib/openehr/rm/data_types/quantity/date_time.rb` 235〜242 行、2.6.1)。
  UTC に直すなら引くのが正しい
- いまはグラフが UTC に直した値を AQL に渡すので、この不具合は表に出ていない。元の文字列を AQL に渡すと出る

## 2. 案

### 案 A(推す): 元の文字列を `text_value` に持つ。列は足さない

- `openehr_rm_data_values` には、DV_DATE_TIME の行では使っていない文字列の列 `text_value` がある(install の migration テンプレート、
  実測)。`GraphBuilder` は DV_DATE_TIME の行に、元の ISO 8601 文字列を `text_value` として入れる。`datetime_value` はいまのまま(並べ替えと SQL 用)
- 読み出し(`DataValues::DvDateTime#to_canonical`、`RmObjectBuilder#dv_date_time` の呼び出し元)は `text_value` を先に使い、無ければ
  いまの `datetime_value.iso8601`
- **migration は要らない**。既存の行は `text_value` が空なので、いままでどおり UTC の値を返す(元の文字列は失われていて、戻せない)
- 裁定は「列を足す変更なので計画でゲート」としていた。案 A は列を足さないので、その前提が変わる。これもゲートで確かめたい

### 案 B: 新しい列 `datetime_text` を足す(Issue の当初の案)

- install の migration テンプレートに列を足し、既存の導入先には追加の migration が要る(generator を足すか、Upgrade note に手順を書く)
- 案 A と比べて得るもの: 列の名前が中身を表す。失うもの: migration の手間と、install テンプレートの変更(出荷物)

### `datetime_value` に入れる値(案 A・B 共通)

- いま: `Time.zone.parse`。日付だけの値は、ホストのタイムゾーンの 0 時
- 案: 変えない。SQL の範囲検索を使っている導入先の結果を変えないため。部分精度の値の `datetime_value` は「その期間の最初の時刻(ホストのタイムゾーン)」と文書に書く

## 3. ゲートで決めてほしいこと

1. 案 A(列を足さない)と案 B(列を足す)のどちらにするか。推すのは A
2. AQL に渡す RM オブジェクトに、元の文字列を使うか:
   - (i) 使う。SELECT は元の値を返す。ただし、1.2 の上流の不具合で、正のオフセット(`+09:00` など)を持つ値の WHERE の比較が誤る。
     上流の修正(openehr-ruby。Issue の文面の案は下)が出るまで、範囲の WHERE の結果が変わる
   - (ii) 上流の修正が出るまで、AQL には UTC に直した値を渡し続ける。canonical JSON(REST の GET、`CanonicalSerializer`)だけ元の値を返す。
     上流の修正が出たら (i) に切り替える
   - 推すのは (ii)。WHERE の結果を、上流の修正の前に変えないため
3. semver: 案 A + (ii) は、読み出しの値が元の文字列に戻る(以前は UTC の値)。読み出しの値が変わるので minor とみる

## 4. 上流の Issue の文面の案(openehr-ruby。投稿は人間)

> **DvDateTime#magnitude applies a positive UTC offset with the wrong sign**
>
> openehr 2.6.1: `DvDateTime.new(value: '2026-03-01T10:00:00+09:00') <=> DvDateTime.new(value: '2026-03-01T11:00:00Z')`
> returns `1`; the first value is 01:00Z, so the answer should be `-1`. It also returns `1` against `09:00Z` and `10:00Z`.
> `magnitude` (`lib/openehr/rm/data_types/quantity/date_time.rb`, the `@timezone.sign == +1` branch) adds the offset's hours and
> minutes; normalising to UTC needs them subtracted (and added for a negative offset).
> Impact: AQL `WHERE` / `ORDER BY` on DV_DATE_TIME values that carry a non-UTC offset compare them wrongly.

## 5. 実装に進むときの Red(ゲートの回答のあと)

- 「DV_DATE_TIME を `2026-03-01` で commit すると、`CanonicalSerializer` が `2026-03-01` を返す」(bug。いまは `2026-02-28T15:00:00Z`)
- 「`2026-03-01T10:00:00+09:00` が、そのまま返る」(bug)
- (i) を選んだ場合: 「AQL の SELECT が `2026-03-01` を返す」(bug)
- regression pin: 全精度の値に対する範囲の WHERE の結果は変わらない。#63 より前に書いた行は、いまの値を返す
- Upgrade note: 既存の行は元に戻らない。案 B なら migration の手順

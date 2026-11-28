# #92 AQL に、記録した日時の文字を渡す(計画)

Issue: [#92](https://github.com/skoba/openehr-rails/issues/92)。裁定: R-20261128-15。
状態: **計画。実装とマージは、openehr 2.10.0 が RubyGems に出てから**(未公開のコードに依存しない)。
下限の引き上げは依存の変更なので、その PR は人間がマージする。

測ったもの: openehr-rails master `a19ec57`(0.15.0)、openehr 2.9.0(RubyGems の最新、2026-11-28)。
openehr の比べ方は、openehr-ruby origin/master `22292d2` の `changelog.d/134-aql-date-time-literal.md`・
`135-aql-value-components.md`・`151-order-by-desc-nulls-last.md` で読んだ(未公開。2.10.0 に入る見込み)。

## 1. いまの姿

- `Aql::DatasetAdapter#materialize` が `to_rm(normalize_date_times: true)` で RM を組む。
  `RmObjectBuilder` は、そのとき次を UTC の時点で作る:
  - `DV_DATE_TIME`(`row.datetime_value`)、`DV_DATE`(`dv.date_value.iso8601`)
  - `HISTORY.origin`・`EVENT.time`・`EVENT_CONTEXT.start_time`(`recorded_time` が時点を返す)
- 実測(master、2.9.0): `context.start_time` を `2026-03-15T09:30:00+09:00` で commit すると、
  `SELECT c/context/start_time/value` は `2026-03-15T00:30:00Z` を返す。REST と `to_rm` は記録したとおり

## 2. openehr 2.10.0 の比べ方(未公開のコードで読んだもの)

- WHERE: 日時そのものも、`.../value` も、書かれた成分を年から順に、両方にある成分だけで比べる。
  共通の精度まで等しければ等しい。時刻帯は両方にあるときだけ当てる。無ければ書かれたとおり
- ORDER BY: いちばん早い時点の順。同じなら粗い値が先。DESC でも値の無い行は最後(#151)
- SELECT・LIKE・MATCHES: `.../value` は書かれた文字のまま
- 日時として読めない字句(ISO 8601 でない、時刻だけ、数)と比べると `ExecutionError`

## 3. 変えること

1. `DatasetAdapter#materialize` は `to_rm` を、`normalize_date_times:` なしで呼ぶ
2. `normalize_date_times:` を `RmObjectBuilder` と `Rm::Composition#to_rm` から外す。
   AQL の道のほかに使う所は無い(`grep` で確かめた: lib・app の呼び出しは `dataset_adapter.rb:63` だけ)。
   残す理由は無いので、外す(公開の API の `to_rm` の引数が減る。semver は棚卸しで)
3. 記録した文字が無い行の扱い(`original_value` が nil、#63 より前の行。構造の日時は #121 より前の行)は、
   時点の `iso8601` を返す。Red で、そういう行がどう組まれるかを測ってから決める
4. 未対応の字句で `ExecutionError` が出るときの扱い: `Aql::Executor` の既存のエラーの道に乗るかを、spec で確かめる
5. コメントの書き直し: `rm_object_builder.rb:65-75`、`dataset_adapter.rb` の `materialize` の上、
   `composition_committer_context_spec.rb:9-11`(round trip は 0.15.0 で済んだ)
6. gemspec の下限: `openehr >= 2.10.0`(いまの `~> 2.6` の上限は、版の行のコメントとあわせて見直す)

scaffold の記録の時刻を UTC で書くこと(R-20261128-9)は変えない。

## 4. spec(Red を先に)

DV_DATE_TIME の項目と `c/context/start_time` の両方で、日時そのもの(`…items[atNNNN]`)と `…/value` の両方の形:

| # | 記録 | 問い | 期待 |
| --- | --- | --- | --- |
| S1 | `2026-03-01` | SELECT `…/value` | `2026-03-01` |
| S2 | `2026-03-01T10:00:00+09:00` | SELECT `…/value` | そのまま |
| W1 | `2026-03-01T08:00:00+09:00` | `>= '2026-03-01'` | 当たる(いまは `2026-02-28T23:00:00Z` で当たらない) |
| W2 | `2026-03-01T08:00:00+09:00`、`2026-02-28T23:30:00Z` | `>= '2026-02-28T23:15:00Z'` | あとの値だけ |
| W3 | `2026-03-01` | `>= '2026-03-01T00:00:00Z'` / `> '2026-03-01T00:00:00Z'` | 当たる / 当たらない |
| O1 | W2 の 2 件と `2026-03-01` | ORDER BY `…/value` ASC・DESC | openehr の並べ方(時点の順。同じなら粗い値が先) |

DV_DATE の項目も、S1・W3 の形で 1 つずつ。

書き換える既存の pin(結果が変わるもの。もとの期待値は PR の本文に書く):
- `composition_committer_structural_date_time_spec.rb:138-139`(AQL が時点を返す pin)
- `datetime_original_value_spec.rb:85`(AQL に UTC を渡す pin)
- ほかは実装の Red で、全体の CI の結果から数える

## 5. 進め方と semver

- PR は 1 つ(1 Issue = 1 PR)。下限の引き上げを含むので、人間がマージする
- openehr 2.10.0 が出るまでに進めるのは、Issue の書き直しとこの計画書だけ
- semver は棚卸しで決める。見込みは **minor**(AQL の SELECT・WHERE・ORDER BY の結果が変わる。
  `to_rm` の引数が減る)。Upgrade note に、結果の変わる形(W1・W3 と、`+09:00` で記録した値の SELECT)を書く
- 変更履歴は `changelog.d/92-aql-committed-date-times.md`

## 6. 気づいたこと(この Issue の外)

- `DV_TIME` は、どの道でも `time_value.strftime('%H:%M:%S')` で組む(時刻帯と部分的な精度が落ちる)。
  #92 の外。別の Issue の候補として報告に書く

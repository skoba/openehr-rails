# #94・#95 公開 API の追加 2 つ(計画)

Issue: skoba/openehr-rails#94(AQL の画面を、問いを入れた状態で開く)、#95(subject_id で EHR を引く)。
裁定: R-20261127-2。基準点: master `c2805cf`。

## 1. #94 AQL の画面の問いを URL から受ける(進める)

- `GET /query?q=...&query_parameters=...`。`q` は入力欄(textarea)に、`query_parameters` は JSON の入力欄に入れる
- 開いただけでは実行しない。実行は、これまでどおりボタン(画面の JS に、読み込み時の実行を足さない)
- 値の検査は、画面の外に出した小さなクラス(`OpenehrRails::QueryConsolePrefill`)で行い、spec で確かめる:
  - 受けるのは文字列だけ(`query_parameters[min]=1` のような入れ子は捨てる)
  - 長さの上限は、それぞれ 10,000 文字。超えたら入れずに、画面にその旨を出す
  - JSON の正しさは、ここでは見ない(実行のときに、いまの画面の検査が見る)
- 値は ERB の既定のエスケープで出す(`raw`・`html_safe` を使わない)。`</textarea><script>` が文字のまま出ることを spec で pin する
- パラメータが無いときは、いまと同じ例の問いと、空の入力欄(regression pin)
- semver: minor(既存の画面に、省略できる URL パラメータを足す)

## 2. #95 subject_id で EHR を引く(ゲート)

仕様: openEHR ITS-REST の EHR API「Get EHR by subject id」(https://specifications.openehr.org/releases/ITS-REST/latest/ehr.html、
状態 STABLE。2026-11-27 に読んだ)。

- `GET /ehr?subject_id=...&subject_namespace=...`。2 つとも必須。`EHR_STATUS.subject.external_ref.id.value` と `.namespace` に照らす
- 200: EHR の資源(`GET /ehr/{ehr_id}` と同じ形)。404: その subject の EHR が無い
- このリポジトリでは `GET /v1/ehr` に足す。応答は、いまの `GET /v1/ehr/:ehr_id` と同じ(`EhrSerializer`)。アクセスの範囲は `:rest_api`

仕様から決まらない点(R-20261127-2 の「止まって報告」に当たる):

1. **同じ subject の EHR が複数あるとき**。`openehr_ehrs` に `(subject_id, subject_namespace)` の一意の制約は無く、
   `POST`・`PUT /v1/ehr` も確かめない(実測: `create_openehr_ehrs.rb` と `OpenehrApi::EhrsController`)。仕様の文は単数で、
   複数のときに触れていない。案:
   - (a) 409 Conflict を返し、本文に一致した `ehr_id` の一覧を書く。作成の側は変えない
   - (b) いちばん古い(`time_created` の早い)EHR を返す
   - (c) 作成の側(`POST`・`PUT /v1/ehr`)で、同じ subject の 2 つめを 409 で拒む。既存の重複は (a) で扱う
   - 推すのは (a)。黙って 1 つを選ばない。(c) は作成の挙動を変える(公開 API の変更)ので、別の判断にしたい
2. **`subject_id`・`subject_namespace` が無い、または空のとき**。仕様は「必須」とするが、この操作の応答に 400 を挙げていない。
   案: 400 と `{ "error": ... }`(このリポジトリのほかの入口と同じ形)。推すのはこれ

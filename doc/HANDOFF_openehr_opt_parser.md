# 引き継ぎプロンプト: openehr gem の OPT パーサ拡張

> このファイルは `openehr` gem 本体（`/home/skoba/src/openehr-ruby`, gem 名
> `openehr`, version 1.3.0, branch master）側で作業するセッションへ渡すための
> プロンプトです。`/home/skoba/src/openehr-ruby` を開いたセッションに以下を
> そのまま貼り付けてください。

---

## あなたへの依頼（プロンプト本文）

`openehr` gem（`/home/skoba/src/openehr-ruby`）の **Operational Template (OPT)
パーサ** を拡張し、実運用の OPT ファイルを解析できるようにしてください。
TDD（t-wada スタイル: 🔴失敗テスト→🟢最小実装→🔵リファクタ、小さく進める）で
進め、既存テストを壊さないこと。

### 背景 / なぜ必要か

姉妹プロジェクト `openehr-rails`（`/home/skoba/src/openehr-rails`）は
`rails g openehr:scaffold <file.opt>` で OPT から Rails 一式を生成します。その
デモ・マニュアルを整備した際、**現行 OPT パーサが対応する制約型が少なく、
解析できる実 OPT が極端に限られる**ことが判明しました。

実機調査（2026-06-26, openehr 1.3.0）の結果:

- ✅ 解析・scaffold 可能: `bmi_calculation.opt`（OBSERVATION）、
  nagara `ProblemList.opt`（EVALUATION, 5項目）、mml の
  `mml_registered_diagnosis`/`mml_lifestyle`/`mml_progress_notes` 等。
- ❌ 解析不可（下記）: バイタル/血圧を含む臨床 OPT の大半。このため
  デモで本来使いたかった **血圧テンプレートが提示できていません**。

ゴールは「臨床的に一般的な OPT（バイタルサイン、検査結果、健診など）を
パースし、`OpenehrRails::Opt::FieldExtractor` がフィールドを抽出できる」状態です。

### 対象ファイル

- パーサ本体: `lib/openehr/parser/opt_parser.rb`
  - 制約型のディスパッチは `send <xsi:type>.downcase, ...`（`attributes`/
    `children`/`c_primitive_object` 内）。つまり XML の `xsi:type="C_DURATION"`
    は `c_duration` メソッドを呼ぶ。**未定義の型 = NoMethodError**。
  - 現在定義済みの制約ハンドラ:
    `c_archetype_root, c_complex_object, c_single_attribute,
    c_multiple_attribute, c_code_phrase, c_primitive_object, c_string,
    c_dv_quantity, c_date, c_date_time, c_integer, c_boolean,
    archetype_slot, constraint_ref, expr_leaf, expr_binary_operator`。
- アーキタイプ ID 検証: `lib/openehr/rm/support/identification.rb:79`
  （`ArchetypeID#value=` が「invalid archetype id form」を raise）。

### 再現手順

`openehr-rails` 経由（FieldExtractor まで含めて確認できる）:

```ruby
# /home/skoba/src/openehr-rails で:
#   bundle exec ruby -Ilib - <<'RUBY'
require 'openehr_rails'
files = {
  'mml4_vital_sign'          => '/home/skoba/src/mml/openEHR/templates/mml4_vital_sign.opt',
  'General_Medical_Examination' => '/home/skoba/src/mml/openEHR/templates/General_Medical_Examination.opt',
  'test_result'              => '/home/skoba/src/mml/openEHR/templates/test_result.opt',
  'LaboratoryTestReport'     => '/home/skoba/src/nagara/app/archetypes/LaboratoryTestReport.opt',
}
files.each do |name, f|
  begin
    opt = OpenehrRails::Opt.parse(f)
    n = OpenehrRails::Opt::FieldExtractor.new(opt).fields.size
    puts "OK   #{name}  fields=#{n}"
  rescue => e
    puts "FAIL #{name}  #{e.class}: #{e.message}"
  end
end
RUBY
```

gem 単体でも、`OpenEHR::Parser::OPTParser.new(File.read(path)).parse` で
再現できます（`openehr-rails` の `OpenehrRails::Opt::Parser` は OPTParser の
サブクラスで、uid 欠落・非有界 occurrence を許容する薄いラッパです）。

### 現在の失敗と原因の当たり

| OPT | エラー | 原因の当たり |
|---|---|---|
| mml4_vital_sign | `NoMethodError: undefined method 'c_duration'` | `C_DURATION` 制約型ハンドラ未実装 |
| General_Medical_Examination | `ArgumentError: invalid archetype id form` | `identification.rb:79` のアーキタイプ ID 正規表現が実 ID に不一致。加えて `C_DV_ORDINAL` も含む |
| test_result | `NoMethodError: undefined method 'text' for nil` | 想定ノード（`rm_type_name` 等）欠落時の nil ガード不足 |
| LaboratoryTestReport | `NoMethodError: undefined method 'text' for nil` | 同上。`DV_IDENTIFIER`（既定値）等の取り扱い |

実 OPT 群で使われている `xsi:type` の調査結果（未対応で要追加の候補）:
**`C_REAL`, `C_DURATION`, `C_DV_ORDINAL`**（高頻度）。ほか実装方針として
`C_DV_TEXT / C_DV_CODED_TEXT / C_DV_COUNT / C_DV_PROPORTION / C_DV_DATE /
C_DV_DATE_TIME / C_DV_TIME / C_DV_INTERVAL` も将来必要になり得ます。

### 依頼内容（作業項目）

1. **未対応の制約型ハンドラを追加**（最低でも `c_real`, `c_duration`,
   `c_dv_ordinal`）。既存ハンドラの実装パターン（`c_dv_quantity`,
   `c_integer` 等）に倣い、`rm_type_name`・`occurrences`・制約値を読み取って
   対応する AM/RM オブジェクトを返す。AM 側に対応クラスが無い型は、まずは
   最小限（rm_type_name と path を保持する複合オブジェクト相当）で「落ちずに
   通す」ことを優先してよい。
2. **nil 安全化**: `.at(...).text` / `attributes['type'].text` 等、ノードが
   無いと落ちる箇所に nil ガードを入れ、未知/欠落要素はスキップして解析継続。
3. **アーキタイプ ID 検証の見直し**（`identification.rb`）: 実 OPT の
   アーキタイプ ID 形式を受理できるよう正規表現を緩和/修正。どの ID 値で
   失敗するかをまず特定してからテストを書くこと。
4. 余裕があれば DV 系（`C_DV_TEXT`/`C_DV_CODED_TEXT`/`C_DV_COUNT` 等）も追加。

### 受け入れ条件

- 上記再現スクリプトの 4 件が `FAIL` から `OK fields=N (N>0)` になる
  （少なくとも `mml4_vital_sign` と血圧を含むバイタル系が通ること）。
- `rake spec`（既存テスト全体）が緑のまま。
- 追加したハンドラ／挙動に対する RSpec を新規 fixture とともに追加。

### 制約・注意

- **TDD（t-wada）厳守**、小さなステップ。直実装が自明な箇所のみ直実装可。
- **`.opt` ファイルは改変しない**。テストには新規 fixture を追加する
  （既存 OPT をコピー or 最小の合成 OPT を作る）。
- 既存の公開挙動・spec を壊さない。
- 完了したら `openehr-rails` 側で `bundle update openehr`（または
  `Gemfile` のパス参照）して `bash script/build_demo.sh` の題材に血圧/バイタル
  テンプレートを追加できるようにすることがゴール（こちらは別途対応）。

### 参考: 利用側（openehr-rails）の前提

- `OpenehrRails::Opt::Parser`（`lib/openehr_rails/opt/parser.rb`）は
  `OpenEHR::Parser::OPTParser` を継承し、`<uid>` 欠落と非有界 occurrence を
  許容する。パーサが返す `OperationalTemplate` の構造に依存して
  `OpenehrRails::Opt::FieldExtractor` が ENTRY/ELEMENT を走査するため、
  **新規制約型でも `rm_type_name` と `path` が正しく付与される**ことが重要。

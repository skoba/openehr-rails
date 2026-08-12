# 引き継ぎプロンプト: openehr gem の `CompositionFactory.create_from_json` 配列変換バグ

> ✅ **解決済み**: openehr 2.0.1 で修正されました。openehr-rails 側は
> `bundle update openehr` で追随済み（2026-08-12）。
> `spec/openehr_rails/rm/create_from_json_roundtrip_spec.rb` を「バグを
> 固定する」specから「修正を回帰させない」specへ書き換え、実際に
> `composition.content.first` が `Pathable` になり AQL クエリが正しく
> ヒットすることを確認済み。
>
> ただし **別の理由で `create_from_json` はまだ `OpenehrRails::Aql::DatasetAdapter`
> の主経路にはできない**: openEHR RM の LOCATABLE は `name` が必須だが、
> `Storable#rm_content` は HISTORY/POINT_EVENT/ITEM_TREE のような構造ノードに
> `name` を書き込んでいない（`RmObjectBuilder` はグラフ→RMオブジェクト変換時に
> `archetype_node_id` からの合成名でこれを埋めている）。そのため実際に
> scaffold されたレコードの `rm_composition` を `create_from_json` に渡すと
> 今も例外になる（`archetype_details.archetype_id`/`template_id` に `_type`
> が無いことに起因する別のエラーが先に出る場合もある）。DatasetAdapter は
> 引き続き `Rm::Composition#to_rm`（RmObjectBuilder）を使う設計のままで良い。
> これらは openehr-rails 側（Storable の正準JSON生成）の課題であり、
> openehr-ruby 側の追加対応は不要。
>
> 以下は元の引き継ぎ文書（歴史的記録として残す）。

> このファイルは `openehr` gem 本体（`/home/skoba/src/openehr-ruby`, gem 名
> `openehr`, version 2.0.0, branch master）側で作業するセッションへ渡すための
> プロンプトです。`/home/skoba/src/openehr-ruby` を開いたセッションに以下を
> そのまま貼り付けてください。

---

## あなたへの依頼（プロンプト本文）

`openehr` gem（`/home/skoba/src/openehr-ruby`）の
`OpenEHR::RM::CompositionFactory.create_from_json` が、正準 JSON の**配列値
属性を再帰的に RM オブジェクトへ変換していない**バグを修正してください。
TDD（t-wada スタイル: 🔴失敗テスト→🟢最小実装→🔵リファクタ、小さく進める）
で進め、既存テストを壊さないこと。

### 背景 / なぜ問題か

姉妹プロジェクト `openehr-rails`（`/home/skoba/src/openehr-rails`）は今回
openehr ~> 2.0 へアップグレードしました。2.0 の README/CHANGELOG が AQL
Dataset への推奨データ供給経路として案内している

```ruby
OpenEHR::RM::CompositionFactory.create_from_json(canonical_json)
```

を実際に試したところ、`content`（および `events`/`items` など多重度を持つ
属性）の要素が **Hash のまま**残り、`OpenEHR::RM::Common::Archetyped::Pathable`
のインスタンスになりません。

`OpenEHR::AQL::Dataset` の唯一の防波堤（`each_ehr` 内 `build_record`）は
**トップレベルの composition オブジェクトだけ** `is_a?(Pathable)` を検査する
ため、これは例外にならず素通りします。しかし AQL エンジンの `CONTAINS` 探索
は `composition.content` の中身が Hash だと何も見つけられず、**エラーなしで
0 件がヒットする**という、最も気づきにくい形の不具合になります。

### 再現手順

```ruby
# /home/skoba/src/openehr-ruby で:
#   bundle exec ruby -e '...' 相当。以下は openehr-rails 側で
#   実際に確認済みの再現コード（spec/openehr_rails/rm/create_from_json_roundtrip_spec.rb
#   に characterization spec として固定済み）
require 'openehr'

json = {
  '_type' => 'COMPOSITION',
  'archetype_node_id' => 'openEHR-EHR-COMPOSITION.report-result.v1',
  'name' => { '_type' => 'DV_TEXT', 'value' => 'test' },
  'language' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'ISO_639-1' }, 'code_string' => 'en' },
  'territory' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'ISO_3166-1' }, 'code_string' => 'US' },
  'category' => { '_type' => 'DV_CODED_TEXT', 'value' => 'event', 'defining_code' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'openehr' }, 'code_string' => '433' } },
  'composer' => { '_type' => 'PARTY_IDENTIFIED', 'name' => 'unknown' },
  'content' => [
    { '_type' => 'OBSERVATION', 'archetype_node_id' => 'openEHR-EHR-OBSERVATION.height.v2', # ... 以下省略、フルは上記 spec 参照
    }
  ]
}

composition = OpenEHR::RM::CompositionFactory.create_from_json(json.to_json)
composition.content.first.class
# => Hash  (期待値: OpenEHR::RM::Composition::Content::Entry::Observation)
composition.content.first.is_a?(OpenEHR::RM::Common::Archetyped::Pathable)
# => false
```

AQL 経由でも確認済み（同じ spec ファイル内）:

```ruby
dataset = OpenEHR::AQL::Dataset.new(ehrs: [{ ehr_id: 'e1', compositions: [composition] }])
query = 'SELECT o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude AS height ' \
        'FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2]'
OpenEHR::AQL.execute(query, dataset).rows
# => []  (該当データは実在するのに 0 件。例外は発生しない)
```

### 原因の当たり

`lib/openehr/rm/factory.rb`:

```ruby
def self.params(param)
  param.each_with_object({}) do |item, parameters|
    key = item.shift
    value = item.shift
    if value.instance_of? Hash
      parameters[key] = Factory.create(value[:_type], **value)
    else
      parameters[key] = value
    end
  end
end
```

`value.instance_of? Hash` のみを変換対象としており、`value.instance_of? Array`
の分岐が無い。`content`/`events`/`items`/`activities`/`participations` など
RM の多重度 1..* 属性はすべて JSON 配列になるため、この経路を通る限り一切
再帰変換されず生の Hash 配列のまま残る。

### 依頼内容（作業項目）

1. **`Factory.params` に配列分岐を追加**: `value.instance_of? Array` の場合、
   各要素が Hash なら `Factory.create(element[:_type], **element)` を適用し、
   Hash でなければそのまま通す（プリミティブ配列を壊さないため）。
2. **`create_from_json` の受け入れテストを追加**: `content`/`events`/`items`
   のように配列の中に polymorphic な RM オブジェクトを含む正準 JSON を渡し、
   復元されたオブジェクトが `is_a?(Pathable)` であることを検証する。
3. 既存の `Factory.params`/`create_from_json` の spec を壊さないこと。
4. 余裕があれば、`OpenEHR::AQL::Dataset` の `build_record` 側にも「トップ
   レベルの composition だけでなく、その配下も再帰的に Pathable を要求する
   か」を検討してほしい（ただし本命の修正は 1〜2 の Factory 側）。トップ
   レベルのみのチェックのままにするなら、README の「Supplying data to AQL」
   節に「content 配下も CompositionFactory.create_from_json で正しく RM
   オブジェクト化されている必要がある（現状はこのバグで壊れている）」旨を
   明記してほしい。

### 受け入れ条件

- 上記再現コードで `composition.content.first.is_a?(Pathable)` が `true`
  になる。
- AQL の `CONTAINS OBSERVATION` を含むクエリが実データにヒットする
  （`rows` が空でなくなる）。
- `rake spec`（既存テスト全体）が緑のまま。
- 追加した挙動に対する RSpec を新規に追加。

### 制約・注意

- **TDD（t-wada）厳守**、小さなステップ。直実装が自明な箇所のみ直実装可。
- 既存の公開挙動・spec を壊さない。
- 完了したら `openehr-rails` 側で `bundle update openehr` し、
  `spec/openehr_rails/rm/create_from_json_roundtrip_spec.rb` の
  「leaves array-valued attributes ... as raw Hashes」系のテストが
  **失敗するようになる**（= 修正の検知）ことを確認してもらうのが良い
  （こちらは別途対応、これは openehr-rails 側の characterization spec
  なので openehr-ruby 側で直す必要はない）。

### 関連: 既知の別バグ（未修正、参考情報）

同じ `Factory` 周りで `OpenEHR::RM::Factory.create('COMPOSITION', **params)`
が `NoMethodError` で落ちる既知のバグが別途あります（`CompositionFactory`
だけ `self.create` のオーバーライドを忘れている）。openehr-ruby 側の
メモリに記録済み・まだ未修正とのことです。本チケットの対象ではありません
が、`Factory.params` を触るなら合わせて見ておくと良いかもしれません。

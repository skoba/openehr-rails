# 引き継ぎプロンプト: openehr gem の `Factory.params`/`convert_value` が `_type` の無いネスト Hash で例外になる

> ✅ **解決済み**: openehr 2.0.2（コミット `8b53b76 Fix: Factory.params/
> convert_value crashes on _type-less non-polymorphic Hash`）で修正されま
> した。2026-08-12、openehr-rails 側で下記ケース1・2の再現コードを 2.0.2
> で再実行し、`archetype_id.class == ArchetypeID` /
> `terminology_id.class == TerminologyID` になることを確認済み。
>
> ただし「関連」セクションに記載の通り、本チケットの修正だけでは実際の
> scaffold レコードの `rm_composition` は `create_from_json` を最後まで
> 通らない（openehr-rails 側の別課題 — 構造ノードの `name` 欠落 — が残って
> いるため、`ArgumentError: name should not be empty` で止まる。これは
> openehr-rails 側の課題であり本チケットの対象外）。
>
> 以下は元の引き継ぎ文書（歴史的記録として残す）。

> このファイルは `openehr` gem 本体（`/home/skoba/src/openehr-ruby`, gem 名
> `openehr`, version 2.0.1, branch master）側で作業するセッションへ渡すための
> プロンプトです。`/home/skoba/src/openehr-ruby` を開いたセッションに以下を
> そのまま貼り付けてください。

---

## あなたへの依頼（プロンプト本文）

`openehr` gem（`/home/skoba/src/openehr-ruby`）の `Factory.params`/
`Factory.convert_value` が、**`_type` キーを持たないネスト Hash**（ARCHETYPE_ID
や TEMPLATE_ID、TERMINOLOGY_ID のような非多相な RM 属性でよくある形）に
遭遇すると、分かりにくい `NoMethodError` で落ちるバグを修正してください。
TDD（t-wada スタイル: 🔴失敗テスト→🟢最小実装→🔵リファクタ、小さく進める）
で進め、既存テストを壊さないこと。

### 背景 / なぜ問題か

姉妹プロジェクト `openehr-rails`（`/home/skoba/src/openehr-rails`）で
openehr 2.0.1（`Factory.params` の配列非再帰変換バグ修正版）を実際に使い、
`OpenEHR::RM::CompositionFactory.create_from_json` に openehr-rails 自身が
生成した正準 JSON（`Storable#to_rm_composition` の出力そのもの）を通した
ところ、**必ず** `NoMethodError: undefined method 'include?' for nil` で
落ちることが分かりました。

原因は `archetype_details.archetype_id` / `.template_id` の値が
`{"value" => "..."}` のように **`_type` を持たない Hash** であることです。
openehr-rails の `Storable#to_rm_composition`
（`lib/openehr_rails/storable.rb`）と `CanonicalSerializer`
（`lib/openehr_rails/rm/canonical_serializer.rb`）はどちらもこの形で
出力しており、これは openEHR の ITS-JSON としても珍しくない書き方です
（ARCHETYPE_ID/TEMPLATE_ID/TERMINOLOGY_ID のように文脈から型が一意に
決まる非多相な属性には `_type` を付けない実装がよくあります）。

つまり **「配列非再帰変換バグ」を直した 2.0.1 でも、openehr-rails 自身が
生成した現実のデータを `create_from_json` に通すことはまだできません**。
別の場所で落ちるだけです。

### 再現手順

```ruby
# /home/skoba/src/openehr-ruby で:
#   ruby -Ilib -e '...'
# (bundle exec だと nokogiri のバージョン不一致でこのチェックアウトの
#  Gemfile.lock がずれており動かないことがあるので、素の -Ilib 実行を推奨)
require 'openehr'

# ケース1: ARCHETYPED.archetype_id / template_id
json = {
  '_type' => 'COMPOSITION',
  'archetype_node_id' => 'openEHR-EHR-COMPOSITION.report-result.v1',
  'archetype_details' => {
    '_type' => 'ARCHETYPED',
    'archetype_id' => { 'value' => 'openEHR-EHR-COMPOSITION.report-result.v1' }, # _type 無し
    'template_id' => { 'value' => 'bmi_calculation' },                          # _type 無し
    'rm_version' => '1.0.4'
  },
  'name' => { '_type' => 'DV_TEXT', 'value' => 'test' },
  'language' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'ISO_639-1' }, 'code_string' => 'en' },
  'territory' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'ISO_3166-1' }, 'code_string' => 'US' },
  'category' => { '_type' => 'DV_CODED_TEXT', 'value' => 'event', 'defining_code' => { '_type' => 'CODE_PHRASE', 'terminology_id' => { '_type' => 'TERMINOLOGY_ID', 'value' => 'openehr' }, 'code_string' => '433' } },
  'composer' => { '_type' => 'PARTY_IDENTIFIED', 'name' => 'unknown' },
  'content' => []
}
OpenEHR::RM::CompositionFactory.create_from_json(json.to_json)
# => NoMethodError: undefined method 'include?' for nil
#    factory.rb:12 Factory.create の type.include?('_') で、type が nil

# ケース2: CODE_PHRASE.terminology_id も同じパターンで落ちる
OpenEHR::RM::Factory.create('CODE_PHRASE',
  terminology_id: { value: 'ISO_639-1' }, code_string: 'en')
# => 同じ NoMethodError
```

いずれも 2026-08-12、openehr 2.0.1（このチェックアウトの HEAD）で実際に
再現を確認済みです。

### 原因の当たり

`lib/openehr/rm/factory.rb`:

```ruby
def self.create(type, **param)
  if type.include? '_'          # type が nil だとここで NoMethodError
    type = type.downcase.camelize
  else
    type = type.capitalize
  end
  class_eval("#{type}Factory").create(params(param))
end

def self.params(param)
  param.each_with_object({}) do |item, parameters|
    key = item.shift
    value = item.shift
    if value.instance_of? Hash
      parameters[key] = Factory.create(value[:_type], **value)  # _type が無いと nil を渡す
    else
      parameters[key] = value
    end
  end
end
```

`Factory.params` は Hash 値を無条件に `value[:_type]` で再帰ディスパッチ
します。`_type` が無ければ `Factory.create(nil, ...)` になり即座に落ちます。

一方で `ArchetypeIdFactory`/`TemplateIdFactory`/`TerminologyIdFactory`
（`factory.rb:268` 付近）は**すでに存在**し、正しく
`ArchetypeID`/`TemplateID`/`TerminologyID` を作れます。しかし
`ArchetypedFactory.create`（`factory.rb:262`）は

```ruby
class ArchetypedFactory
  def self.create(param)
    OpenEHR::RM::Common::Archetyped::Archetyped.new(**param)
  end
end
```

のように `param`（`Factory.params` 済みの Hash）をそのまま `Archetyped.new`
に渡すだけで、`archetype_id:`/`template_id:` の値を上記の専用ファクトリ
経由に変換していません（`Factory.params` の汎用再帰に委ねているが、それには
`_type` が要る、という循環）。「非多相な属性は専用ファクトリで確定的に
変換する」という設計はすでにあるのに、`ARCHETYPED` では配線されていない、
という状態です。`CODE_PHRASE` 側の `terminology_id` も同様の疑いがあります
（`CodePhraseFactory` があれば確認してください）。

### 依頼内容（作業項目）

1. **`ArchetypedFactory.create` を直す**: `archetype_id`/`template_id` を
   Hash のまま `Archetyped.new` に渡さず、既存の
   `ArchetypeIdFactory.create`/`TemplateIdFactory.create` 経由で明示的に
   変換してから渡す。
2. **`CODE_PHRASE` 変換も同様に**: `terminology_id` を
   `TerminologyIdFactory.create` 経由に。
3. **同種の非多相サブ属性が他に無いか棚卸し**（`OBJECT_VERSION_ID` など）。
   同じパターンで個別に直すか、あるいは `Factory.params`/`convert_value`
   自体に「`_type` の無い Hash はそのまま（未変換の Hash として）返す」
   という保守的なフォールバックを入れて汎用的に防ぐか、どちらが良いかは
   お任せします（後者は「本来変換すべきなのに気付かない」リスクとの
   トレードオフがあるので、個別ファクトリで明示的に直す前者の方が
   安全だと思います）。
4. **受け入れテストを追加**: 上記2つの再現コードが例外にならず、正しい
   型（`ArchetypeID`/`TemplateID`/`TerminologyID`）のオブジェクトを持つ
   ことを検証する。
5. 既存の `Factory.params`/`create_from_json` の spec を壊さないこと。

### 受け入れ条件

- 上記の再現コード2件がどちらも例外にならず、`archetype_id.class` が
  `ArchetypeID`、`terminology_id.class` が `TerminologyID` になる。
- `rake spec`（既存テスト全体）が緑のまま。
- 追加した挙動に対する RSpec を新規に追加。

### 制約・注意

- **TDD（t-wada）厳守**、小さなステップ。直実装が自明な箇所のみ直実装可。
- 既存の公開挙動・spec を壊さない。
- 完了したら `openehr-rails` 側で `bundle update openehr` し、実際の
  scaffold レコードの `rm_composition` を `create_from_json` に通しても
  この理由では落ちなくなることを確認してもらうのが良い（ただし
  **これだけでは最後まで通りません**。下記「関連」参照）。

### 関連（本チケットの対象外、参考情報）

- `OpenEHR::RM::Factory.create('COMPOSITION', **params)` が
  `NoMethodError` で落ちる既知のバグ（`CompositionFactory` だけ
  `self.create` のオーバーライドを忘れている）は、本チケットとは別件です。
  2026-08-12、2.0.1 でも再現を確認しましたが、すでに openehr-ruby 側の
  メモリに記録済み・対象外として扱ってください。
- 本チケットを直しても、openehr-rails 側の別課題（`Storable#rm_content`
  が `HISTORY`/`POINT_EVENT`/`ITEM_TREE` のような構造ノードに openEHR RM
  で必須の `name` を書き込んでいない）が残っているため、実際の scaffold
  レコードを `create_from_json` に最後まで通すには openehr-rails 側の
  追加対応も必要です。これは openehr-rails 側の課題なので、こちらでは
  対応不要です。

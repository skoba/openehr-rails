# 引き継ぎプロンプト: openehr gem への軽い要望・提案 3件（2026-08-13 時点）

> このファイルは `openehr` gem 本体（`/home/skoba/src/openehr-ruby`, gem 名
> `openehr`, version 2.1.0, branch master）側で作業するセッションへ渡すための
> プロンプトです。`/home/skoba/src/openehr-ruby` を開いたセッションに以下を
> そのまま貼り付けてください。
>
> これまでの3件の引き継ぎ文書（OPTパーサ拡張・`create_from_json`配列変換
> バグ・`Factory` `_type`欠落バグ）はいずれも解決済みです。今回は「バグ修正
> 依頼」ではなく、姉妹プロジェクト `openehr-rails` を実際に運用する中で
> 気づいた軽い提案・要望3件です。急ぎでも必須でもないので、他の作業の
> 合間に検討いただければ十分です。

---

## あなたへの依頼（プロンプト本文）

以下3件について、対応するかどうかも含めて検討してもらえると嬉しいです。
対応する場合は TDD（t-wada スタイル: 🔴失敗テスト→🟢最小実装→🔵リファクタ、
小さく進める）で進め、既存テストを壊さないようにお願いします。

---

### 1. `OpenEHR::RM::Factory.create('COMPOSITION', **params)` が2.0.0〜2.1.0まで4リリース連続で `NoMethodError`

`CompositionFactory` だけ `self.create` のオーバーライドを忘れているため、
汎用ディスパッチャに落ちて内部で型エラーになります。2.0.2 時点の引き継ぎ
文書（`doc/HANDOFF_openehr_factory_missing_type.md` の「関連」節）で既に
一度触れていますが、`openehr` 側の既存メモリで追跡中とのことでした。
2.0.0 → 2.0.1 → 2.0.2 → 2.1.0 と4リリースをまたいでまだ再現するため、
念のため再掲します。

#### 再現手順（2026-08-13、2.1.0 で再確認済み）

```ruby
# /home/skoba/src/openehr-ruby で: bundle exec ruby -e '...' 相当
require 'openehr'

OpenEHR::RM::Factory.create('COMPOSITION',
  archetype_node_id: 'openEHR-EHR-COMPOSITION.report-result.v1',
  name: { _type: 'DV_TEXT', value: 'test' },
  language: { _type: 'CODE_PHRASE', terminology_id: { _type: 'TERMINOLOGY_ID', value: 'ISO_639-1' }, code_string: 'en' },
  territory: { _type: 'CODE_PHRASE', terminology_id: { _type: 'TERMINOLOGY_ID', value: 'ISO_3166-1' }, code_string: 'US' },
  category: { _type: 'DV_CODED_TEXT', value: 'event', defining_code: { _type: 'CODE_PHRASE', terminology_id: { _type: 'TERMINOLOGY_ID', value: 'openehr' }, code_string: '433' } },
  composer: { _type: 'PARTY_IDENTIFIED', name: 'unknown' },
  content: []
)
# 2.0.2: NoMethodError: undefined method 'include?' for nil
# 2.1.0: NoMethodError: undefined method 'capitalize' for an instance of Hash
# （エラーメッセージの文言はリリースごとに変わっていますが、根本原因は
#   同じ「CompositionFactory.self.create 未定義」です）
```

openehr-rails 側は `CompositionFactory.create_from_json(json)` を直接使う
ことで回避できているので、緊急度は高くありません。ただ、`Factory.create`
は他の全RM型で動く汎用エントリポイントなので、`COMPOSITION` だけ罠がある
状態は初見のユーザーが踏みやすいかもしれません。

---

### 2. AQL実行ギャップの残り4件

2.1.0 で `SELECT TOP` と EHR-root プレディケートの2件が要望なしに修正されて
いて（ありがとうございます、`openehr-rails` 側は特に対応不要でした）、残る
実行ギャップは以下の4件です。`openehr-rails` の
`OpenehrRails::Aql::QueryValidator` が「パースは通るが実行できない」ことを
検知してユーザーに分かりやすいエラーを返すために明示的にガードしている
構文で、2026-08-13、2.1.0 で以下の通り再現を確認済みです
（`spec/openehr_rails/aql/query_validator_spec.rb` に固定化済み）。

```ruby
require 'openehr/aql'

# 1. WHERE句の LIKE
OpenEHR::AQL.parse("SELECT c FROM EHR e CONTAINS COMPOSITION c WHERE c/archetype_node_id LIKE 'foo%'")
# パースは通る（実行時の挙動は openehr-rails 側では未検証、QueryValidator が事前に弾いている）

# 2. WHERE句の MATCHES
OpenEHR::AQL.parse("SELECT c FROM EHR e CONTAINS COMPOSITION c WHERE c/archetype_node_id MATCHES {'a', 'b'}")

# 3. CONTAINS内の standardPredicate/nodePredicate（アーキタイプpredicateではなく [at0004] 形式）
OpenEHR::AQL.parse('SELECT c FROM EHR e CONTAINS COMPOSITION c CONTAINS ELEMENT e2[at0004]')

# 4. SELECTで集約列と非集約列の混在
OpenEHR::AQL.parse('SELECT c/archetype_node_id, COUNT(c) FROM EHR e CONTAINS COMPOSITION c')
```

優先度についてはこちら側から特に要望はなく、実際の下流利用（openehr-rails
の AQL コンソール・REST API）で現状ブロックされている構文をフラットに
列挙しただけです。どれから着手するかは開発側の判断にお任せします。

---

### 3.（軽い提案）Rubyサポートバージョンを下げる変更のsemver上の見え方

2.0.2 で Ruby 3.1/3.3 を、2.1.0 で Ruby 3.2 をそれぞれ落とした際、
`History.txt` にはどちらも明記されていて分かりやすかったのですが、
`gem.add_dependency('openehr', '~> 2.0')` のような依存側の制約は
マイナー/パッチいずれのリリースも無条件で許容してしまいます。そのため
依存側は `bundle update openehr` を実行しただけでは変更に気づけず、CIの
古いRubyレグだけが突然解決不能になる、という形で気づくことになります
（実際、今回 `openehr-rails` 側で2.1.0への更新作業中にこれを事前に検知し、
`required_ruby_version`とCIマトリクスを合わせて更新する形で対応しました。
`.github/workflows/ci.yml` 参照）。

もし可能であれば、「`required_ruby_version` を引き上げる変更は次のマイナー
ではなくメジャーバージョンで行う」という運用にしていただけると、
`~> 2.0` のような緩い制約に依存している側でも安全に追随できるかと思います。
とはいえこれは強い要望ではなく、選択肢の一つとして共有するだけです。
現状の運用（`History.txt` へのはっきりした明記）自体、十分に親切だと
思っています。

---

### 制約・注意

- 対応する場合は **TDD（t-wada）厳守**、小さなステップで。
- 既存の公開挙動・spec を壊さない。
- 3件とも独立した提案なので、どれか1件だけ対応する、あるいは全部見送る、
  どちらでも問題ありません。

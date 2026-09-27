# Iteration 7：仕様から実装のテストを作る

Iteration 6までに決めた仕様を，TypeScriptで実装する．
仕様から生成したトレースを実装に流し，実装が仕様と同じ状態を通るかを確かめる．
新しい要求文はない．

作業はすべて，このディレクトリ(`iterations/iteration-7/exercise`)で行う．
このディレクトリの仕様とテストは，Iteration 6の模範解答と同じである．

## 7-1 準備

リポジトリの直下で次を実行し，検査が通ることを確かめる．

```sh
mise run verify iterations/iteration-7/exercise
```

```text
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 4m ago)
Lockfile is up to date, resolution step is skipped
Done in 23ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-7/exercise
ok  Quintの評価器とApalache

iterations/iteration-7/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  quint verify(時相論理の性質)
ok  状態遷移図
Finished in 29.12s
```

## 7-2 基礎知識と構文

次を読む．

- [モデルベーステスト](../../../../docs/concepts/model-based-testing.md)
- [仕様と実装の対応(詳細化)](../../../../docs/concepts/refinement.md)
- [Iteration 7の構文とコマンド](../../../../docs/quint/iteration-7.md)

読んだら，次を試す．

1. [Iteration 7の構文とコマンド](../../../../docs/quint/iteration-7.md)の`quint run`のコマンドで，トレースを1本出力する．
   出力したJSONで，2つ目の状態のアクションの名前と，`orderStatus`の値を確かめる．
2. 同じコマンドで`--seed`の値を変え，トレースがどう変わるかを確かめる．

## 7-3 実装とトレースのテスト

`impl/`を作り，実装とテストを書く．

```text
impl/
  src/shop.ts          ECショップの注文処理
  test/trace.test.ts   仕様のトレースを実装に流すテスト
```

実装は，状態を受け取って次の状態を返す関数で書く．HTTPやDBは扱わない．
実装の状態の型は，次のとおりとする．

| 名前 | 型 | 内容 |
| --- | --- | --- |
| `stock` | `Record<string, number>` | 商品ごとの在庫数 |
| `reservedItems` | `Record<string, string[]>` | 注文ごとの，引き当てた商品(名前の順) |
| `orderStatus` | `Record<string, OrderStatus>` | 注文ごとの状態 |
| `attempts` | `Record<string, number>` | 注文ごとの，決済を依頼した回数 |
| `refunds` | `Record<string, number>` | 注文ごとの，返金した回数 |

商品と注文の設定(`initialStock`，`orderItems`，`maxAttempts`)は，仕様の定数と同じ値を引数で渡す．
仕様のアクションごとに関数を作る．
条件を満たさない呼び出しは，例外にする．

テストでは，`tools/lib/itf.ts`の`generateTraces`で仕様からトレースを生成し，各ステップのアクションを実装の関数の呼び出しに変える．
呼び出しのあとの実装の状態を，トレースの次の状態のうち，上の表の状態変数と比べる．

## 7-4 仕様と実装の対応

仕様の状態変数とアクションを，ECショップ(実装)が担当するものと，環境(決済代行サービスと配送システム)が担当するものに分ける．
環境のアクションは，テストで実装を呼ばずに読み飛ばす．
分け方を表にしてから，7-3のテストのアクションの対応を書く．

時間切れのあとの成功の通知で返金するかどうかは，決済代行サービスが課金した回数によって決まる．
実装はその値をどう知るかを考え，関数の引数を決める．

## 7-5 検査と不一致

テストを実行する．

```sh
pnpm exec vitest run iterations/iteration-7/exercise/impl
```

不一致が出たら，違いの出たステップとアクション，状態変数を読み取り，実装を直す．
すべて通ったら，実装にわざと誤りを入れて(たとえば，断った注文の商品を在庫に戻さない)，テストが見つけるかを確かめる．

実装に流すすべてのアクションが，生成したトレースに現れているかも確かめる．
現れないアクションがあれば，トレースの本数や長さを増やす．

## 7-6 決定と反映

仕様が実装に課す前提(仕様の1つのアクションを，実装でどう守るか)を，`requirements.md`の決定事項に`### Iteration 7`として書く．
`mise run verify iterations/iteration-7/exercise`で，実装のテストを含むすべての検査が通ることを確かめる．

## 7-7 振り返り

1. 自分の実装とテストを，模範解答と比べる．
2. モデルベーステストで見つからない実装の誤りには，どんなものがあるか．
3. HTTPやDBを含む実際のシステムで，7-6の前提を守るには，何が必要か．
4. Iteration 0から7までで，要求文のどの言葉の意味を決め直したかを振り返る．

## 7-8 発展課題

`mise run check`をCI(GitHub Actionsなど)で実行する設定を考える．
コンテナのイメージを使う方法と，CIの上でmiseとQuintの評価器を入れる方法を比べる．

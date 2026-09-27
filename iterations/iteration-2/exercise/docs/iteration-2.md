# Iteration 2：決済と時間切れ

在庫を引き当てたあとの，決済の流れを仕様にする．
決済代行サービスと，決済の結果の通知，時間切れ監視ジョブをモデル化し，それらの出来事の前後関係で起きる問題を検査する．

作業はすべて，このディレクトリ(`iterations/iteration-2/exercise`)で行う．
このディレクトリの仕様とテストは，Iteration 1の模範解答と同じである．

## 2-1 準備

リポジトリの直下で次を実行し，検査が通ることを確かめる．

```sh
mise run verify iterations/iteration-2/exercise
```

```text
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 21m ago)
Lockfile is up to date, resolution step is skipped
Done in 20ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-2/exercise
ok  Quintの評価器とApalache

iterations/iteration-2/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  状態遷移図
Finished in 8.73s
```

`requirements.md`の要求に，`### Iteration 2`の要求が加わっている．

## 2-2 基礎知識と構文

次を読む．

- [環境のモデル化](../../../../docs/concepts/environment-modeling.md)
- [非同期メッセージ](../../../../docs/concepts/async-messaging.md)
- [時間の抽象化](../../../../docs/concepts/time-abstraction.md)
- [Iteration 2の構文とコマンド](../../../../docs/quint/iteration-2.md)

読んだら，REPLで次を試す．

1. タプルの集合`Set(("a", true), ("b", false))`から，2番目の要素が`true`のものの数を求める．
2. `Set(1, 2)`と`Set(2, 3)`の和集合から，`1`を除いた集合を作る．
3. 型`Mode`(`On`または`Off`)を定義し，`On`と`Off`が等しければ`"same"`，そうでなければ`"different"`になる条件式を書く．

## 2-3 シナリオのテスト

Iteration 2で加わった要求文を読む．

- 在庫を引き当てたら，決済代行サービスに決済を依頼する．
- 決済の結果は決済代行サービスから通知で届く．成功なら注文を確定し，失敗なら引当を解除する．
- 一定時間内に決済の結果が届かない注文は，時間切れ監視ジョブが引当を解除する．
- 例：決済が成功すると，注文は確定し，在庫は0個のままである．
- 例：決済が失敗するか時間切れになると，引当を解除し，在庫は1個に戻る．

決済代行サービスは，ECショップの外にある環境である．
決済の結果(成功または失敗)と，通知が届く時点は，ECショップには決められない．
時間切れも，決済待ちの間ならいつでも起きうる出来事として書く．
仕様では，次の名前を使う．

| 名前 | 種類 | 内容 |
| --- | --- | --- |
| `AwaitingPayment` | `OrderStatus`の値 | 在庫を引き当て，決済の結果を待っている状態．`Reserved`の代わり |
| `Confirmed`，`PaymentFailed`，`Expired` | `OrderStatus`の値 | 確定した状態，決済が失敗した状態，時間切れになった状態 |
| `PaymentStatus` | 型 | 決済代行サービスでの決済の状態．`NotRequested`，`Requested`，`Succeeded`，`Failed` |
| `PaymentResult` | 型 | 通知される決済の結果．`Success`，`Failure` |
| `payment` | 状態変数 | 注文ごとの決済の状態 |
| `notifications` | 状態変数 | 送られたが，まだ受け取っていない通知．`(注文, 結果)`の集合 |
| `reserve(order: str)` | アクション | 在庫を引き当て，決済を依頼する |
| `processPayment(order: str, result: PaymentResult)` | アクション | 決済代行サービスが決済を行い，結果を通知する |
| `receiveNotification(order: str, result: PaymentResult)` | アクション | 通知を受け取り，要求文のとおりに注文を変える |
| `expire(order: str)` | アクション | 時間切れ監視ジョブが，決済待ちの注文の引当を解除する |

`step`では，注文に加えて，決済の結果も`nondet`で選ぶ．

`Reserved`が`AwaitingPayment`に変わるので，既存のテストの期待値が変わる．
直すテストを先に挙げてから，要求文の2つの例をテストにする．

## 2-4 性質

要求文によれば，引当を解除すると在庫が戻る．
在庫の数と，引当中や確定した注文の数の間に成り立つべき関係を，不変条件として書く．
名前は`invStockConsistent`とする．

## 2-5 検査と反例

2つの不変条件をまとめて検査する．

```sh
quint run shop.qnt --invariants invStockNonNegative invStockConsistent --max-samples=1000 --seed=1
quint verify shop.qnt --invariants invStockNonNegative invStockConsistent
```

反例が出たら，次の問いに答える．

1. 最後の状態で，在庫の数と注文の状態の関係はどう崩れているか．
2. 決済の依頼，決済，通知の受け取り，時間切れは，どの順番で起きたか．
3. その順番で，通知を受け取った時点の注文の状態は何だったか．
4. 要求文は，その場合の振る舞いについて何を決めていないか．
5. 実際のシステムで，この順番はどんなときに起きるか．

## 2-6 決定と反映

2-5で見つけた抜けについて，振る舞いを決める．
決済の結果が成功の場合と失敗の場合の両方について決める．
決めたら，これまでと同じく，決定事項，仕様，テスト，状態遷移図を更新し，`mise run verify`で検査を通す．

## 2-7 振り返り

1. 自分の決定事項を，模範解答と比べる．顧客から見て，それぞれの決定はどう見えるか．
2. 2-3のテストのうち，時間切れのテストと成功のテストは，それぞれ通っていた．それでも反例が出たのはなぜか．
3. 決済代行サービスを「いつも成功する」と書いていたら，何が見つからなかったか．
4. 状態遷移図で，`Expired`になった注文がその後どうなるかを確かめる．図に現れない変化(決済の状態の変化)は，どこで確かめるか．

## 2-8 発展課題

2-6とは別の決定として，「時間切れのあとに成功の通知が届いたとき，在庫が残っていれば注文を確定し，残っていなければ返金する」を考える．
この決定を仕様にし，不変条件が成り立つかを検査する．

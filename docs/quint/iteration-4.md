# Iteration 4の構文とコマンド

Iteration 4で初めて使う，Quintの構文とコマンドを説明する．
概念の説明は，[安全性と活性](../concepts/safety-and-liveness.md)，[時相論理](../concepts/temporal-logic.md)，[公平性](../concepts/fairness.md)，[有界モデル検査と全状態探索](../concepts/bounded-and-exhaustive.md)にある．

例には，信号機の仕様を使う．

```quint
// 信号機の仕様．
module trafficLight {
  type Light = Red | Yellow | Green

  var light: Light

  action init = all { light' = Red }
  action toGreen = all { light == Red, light' = Green }
  action toYellow = all { light == Green, light' = Yellow }
  action toRed = all { light == Yellow, light' = Red }
  action step = any { toGreen, toYellow, toRed }

  // 公平性の仮定で使う，状態変数の組．
  val vars = (light)

  // 信号の切り替えは，切り替えられる限り，いつか必ず起きる．
  temporal switchIsFair = weakFair(step, vars)

  // 赤になったら，いつか青になる．
  temporal liveGreenAfterRed = always(light == Red implies eventually(light == Green))

  // 公平性を仮定すると，赤になったら，いつか青になる．
  temporal liveGreenAfterRedFair = switchIsFair implies always(light == Red implies eventually(light == Green))
}
```

## 引数のある定義

`def 名前(引数: 型): 型 = 式`は，引数を取る定義である．
状態変数を読み，注文ごとの条件などに名前を付けるのに使う．

```quint
def unsettled(o: str): bool = charges.get(o) > refunds.get(o) and orderStatus.get(o) != Confirmed
```

`val`は引数を取れない．引数が必要なときは`def`を使う．

## 時相論理の性質

`temporal`で，実行全体についての性質を定義する．

| 書き方 | 意味 |
| --- | --- |
| `always(P)` | いつも`P` |
| `eventually(P)` | いつか`P` |
| `always(P implies eventually(Q))` | `P`になれば，いつか`Q` |

このハンズオンでは，活性の名前を`live`で始める．

## 公平性

`weakFair(アクション, 状態変数の組)`は，そのアクションの弱い公平性を表す時相論理の式である．
状態変数の組は，仕様のすべての状態変数をタプルにしたものである．

公平性は，性質の前提として`implies`でつなぐ．
「公平性が成り立つ実行では，性質が成り立つ」という意味になる．

注文ごとのアクションに公平性を仮定するときは，`forall`で並べる．

```quint
temporal expireIsFair = ORDERS.forall(o => weakFair(expire(o), vars))
```

## TLCで検査する

時相論理の性質は，`--backend=tlc`を付けてTLCで検査する．
`--temporal`に性質の名前を書く．

```sh
quint verify --backend=tlc trafficLight.qnt --temporal=liveGreenAfterRed
```

TLCは経過のログを多く出す．反例は`Error: The following behavior constitutes a counter-example:`の後にある．
公平性を仮定しない`liveGreenAfterRed`の反例は，次のようになる．

```text
Error: Temporal properties were violated.

Error: The following behavior constitutes a counter-example:

State 1: <Initial predicate>
light = [Red |-> [tag |-> "UNIT"]]

State 2: Stuttering
Finished checking temporal properties in 00s at 2026-09-27 05:29:56
4 states generated, 3 distinct states found, 0 states left on queue.
Finished in 00s at (2026-09-27 05:29:56)

[violation] Found an issue (882ms).
error: found a counterexample
```

公平性を仮定した`liveGreenAfterRedFair`は，検査を通る．

```text
Model checking completed. No error has been found.
...
[ok] No violation found (883ms).
```

## TLCの反例の読み方

TLCの反例は，TLA+の記法で表示される．
Quintの記法との対応は次のとおりである．

| TLA+の記法 | Quintの記法 |
| --- | --- |
| `/\ stock = 1` | 状態変数`stock`の値が`1` |
| `[o1 \|-> 0, o2 \|-> 0]` | `Map("o1" -> 0, "o2" -> 0)` |
| `[Red \|-> [tag \|-> "UNIT"]]` | `Red`(値を持たないバリアント) |
| `[Processed \|-> [Success \|-> [tag \|-> "UNIT"]]]` | `Processed(Success)` |
| `{<<"o1", [Success \|-> [tag \|-> "UNIT"]]>>}` | `Set(("o1", Success))` |
| `State 2: <checkStock line ...>` | 状態2は，アクション`checkStock`で作られた |
| `State N: Stuttering` | 状態N-1から先，何も起きずに止まり続ける |
| `State N: Back to state M` | 状態Mに戻り，その間を繰り返し続ける |

活性の反例の最後は，`Stuttering`か`Back to state`で終わる．
どちらも，良いことが永遠に起きない実行を表す．

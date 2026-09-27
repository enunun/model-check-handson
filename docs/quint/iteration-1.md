# Iteration 1の構文とコマンド

Iteration 1で初めて使う，Quintの構文とコマンドを説明する．
概念の説明は，[非決定性](../concepts/nondeterminism.md)，[インターリーブと原子性](../concepts/interleaving-and-atomicity.md)，[デッドロック](../concepts/deadlock.md)にある．

## 集合

`Set(要素, ...)`は集合である．要素の順番と重複は区別しない．
型は`Set[要素の型]`と書く．

| 書き方 | 意味 |
| --- | --- |
| `S.contains(x)` | `x`が`S`の要素か |
| `S.map(x => 式)` | 各要素に式を適用した集合 |
| `S.mapBy(x => 式)` | 各要素をキーとし，式の値を値とするマップ |

`x => 式`は，引数`x`を受け取って式の値を返す関数(ラムダ式)である．
引数を使わないときは，`_ => 式`と書く．

```text
>>> Set("o1", "o2").contains("o1")
true
>>> Set(1, 2, 3).map(x => x * 10)
Set(10, 20, 30)
>>> Set("o1", "o2").mapBy(o => 0)
Map("o1" -> 0, "o2" -> 0)
>>> Set("o1", "o2").mapBy(_ => "NotPlaced")
Map("o1" -> "NotPlaced", "o2" -> "NotPlaced")
>>> Set(1, 2) == Set(2, 1)
true
```

## 非決定的な選択

`nondet 名前 = 集合.oneOf()`は，集合の要素を1つ非決定的に選び，名前を付ける．
続く式で，その名前を使える．
アクションの中で使うときは，全体を`{ }`で囲む．

```quint
action step = {
  nondet order = ORDERS.oneOf()
  any {
    checkStock(order),
    reserve(order),
  }
}
```

REPLでは，選ばれた値を確かめられる．
次の`pick`は，1，2，3のどれかを`picked`にする．

```text
>>> var picked: int
>>> action init = picked' = 0
>>> action pick = { nondet x = Set(1, 2, 3).oneOf() picked' = x }
>>> init
true
>>> pick
true
>>> picked
3
```

`quint run`は選び方をランダムに決め，`quint verify`はすべての選び方を調べる．

## 実行の数(`--max-samples`)

`quint run`の`--max-samples`は，ランダムに作る実行の数である．
数が少ないと，反例を含む実行が作られず，見逃すことがある．

```text
$ quint run shop.qnt --invariant=invStockNonNegative --max-samples=1 --seed=1
An example execution:

[State 0] { orderStatus: Map("o1" -> NotPlaced, "o2" -> NotPlaced), stock: 1 }

[State 1] { orderStatus: Map("o1" -> Checked, "o2" -> NotPlaced), stock: 1 }

[State 2] { orderStatus: Map("o1" -> Reserved, "o2" -> NotPlaced), stock: 0 }

[State 3] { orderStatus: Map("o1" -> Reserved, "o2" -> Rejected), stock: 0 }

[ok] No violation found (15ms at 67 traces/second).
Trace length statistics: max=4, min=4, average=4.00
You may increase --max-samples and --max-steps.
Use --verbosity to produce more (or less) output.
Use --seed=0x1 --backend=rust to reproduce.
```

同じ仕様でも，`--max-samples=5`にすると反例が見つかる．
`[ok] No violation found`は「作った実行の中には反例がなかった」という意味であり，性質が成り立つという意味ではない．

## デッドロックの検査を切る

すべての注文が決着すると，どのアクションも起きなくなる．
`quint verify`は，この状態をデッドロックとして報告する．

```text
$ quint verify shop.qnt --invariants invStockNonNegative
An example execution:

[State 0] { orderStatus: Map("o1" -> NotPlaced, "o2" -> NotPlaced), stock: 1 }

[State 1] { orderStatus: Map("o1" -> NotPlaced, "o2" -> Checked), stock: 1 }

[State 2] { orderStatus: Map("o1" -> Checked, "o2" -> Checked), stock: 1 }

[State 3] { orderStatus: Map("o1" -> Reserved, "o2" -> Checked), stock: 0 }

[State 4] { orderStatus: Map("o1" -> Reserved, "o2" -> Rejected), stock: 0 }

[violation] Found an issue (5226ms).
error: reached a deadlock
```

最後の状態では，どちらの注文も最終的な状態になっている．
これは正常な終わりなので，`--apalache-config`でデッドロックの検査を切る．
`mise run verify`はTLCで検査し，デッドロックを誤りとして扱わない．

```text
$ quint verify shop.qnt --invariants invStockNonNegative --apalache-config=../../../tools/apalache.json
[ok] No violation found (4896ms).
You may increase --max-steps.
Use --verbosity to produce more (or less) output.
```

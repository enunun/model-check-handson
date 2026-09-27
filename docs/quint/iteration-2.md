# Iteration 2の構文とコマンド

Iteration 2で初めて使う，Quintの構文とコマンドを説明する．
概念の説明は，[環境のモデル化](../concepts/environment-modeling.md)，[非同期メッセージ](../concepts/async-messaging.md)，[時間の抽象化](../concepts/time-abstraction.md)にある．

## タプル

`(値, 値, ...)`はタプルである．`._1`，`._2`で要素を取り出す．
型は`(型, 型)`と書く(例：`(str, int)`)．

```text
>>> ("o1", 5)
("o1", 5)
>>> ("o1", 5)._1
"o1"
```

## 集合の操作

| 書き方 | 意味 |
| --- | --- |
| `S.union(T)` | `S`と`T`の和集合 |
| `S.exclude(T)` | `S`から`T`の要素を除いた集合 |
| `S.filter(x => 条件)` | 条件を満たす要素だけの集合 |
| `S.size()` | 要素の数 |
| `Set()` | 空の集合 |

```text
>>> Set(("o1", 5)).union(Set(("o2", 3)))
Set(("o1", 5), ("o2", 3))
>>> Set(("o1", 5), ("o2", 3)).exclude(Set(("o1", 5)))
Set(("o2", 3))
>>> Set(1, 2, 3, 4).filter(x => x > 2)
Set(3, 4)
>>> Set(1, 2, 3, 4).filter(x => x > 2).size()
2
```

## 条件式

`if (条件) 式 else 式`は，条件によって値を選ぶ．

```text
>>> if (3 > 2) "yes" else "no"
"yes"
```

アクションの中でも使える．
条件によって状態変数の変え方が違うときは，それぞれの場合を`all { ... }`で書く．
`else if`で場合を続けられる．

```quint
action receive(result: Result): bool = all {
  inbox.contains(result),
  inbox' = inbox.exclude(Set(result)),
  if (result == Success) all {
    count' = count + 1,
  } else all {
    count' = count,
  },
}
```

## 値の多い型

バリアント型の値が多いときは，1行に1つずつ`|`で始めて書ける．

```quint
type OrderStatus =
  | NotPlaced
  | Checked
  | AwaitingPayment
```

## 状態変数を増やしたとき

アクションは，すべての状態変数の次の値を決める．
状態変数を加えたら，既存のすべてのアクションに，その変数の次の値(変えないなら`x' = x`)を加える．
加え忘れると，`quint typecheck`が次のような誤りを出す．
次の例では，`receive`は`inbox`と`count`を決めているが，`forget`は`inbox`しか決めていない．

```text
 Error [QNT000]: Expected [inbox,count] and [inbox] to be the same
...
  20:   action step = any { receive(Success), forget }
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

error: typechecking failed
```

`any`で並べるアクションは，すべて同じ状態変数の次の値を決めていなければならない．

## 複数の不変条件を検査する

`--invariants`に，名前を空白で区切って並べる．
破れた不変条件には`❌`が付く．

```sh
quint run shop.qnt --invariants invStockNonNegative invStockConsistent --max-samples=1000 --seed=1
quint verify shop.qnt --invariants invStockNonNegative invStockConsistent
```

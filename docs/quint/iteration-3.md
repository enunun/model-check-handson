# Iteration 3の構文とコマンド

Iteration 3で初めて使う，Quintの構文とコマンドを説明する．
概念の説明は，[メッセージの配送保証](../concepts/delivery-guarantees.md)，[冪等性](../concepts/idempotency.md)にある．

## 値を持つバリアント型

バリアント型の値は，別の型の値を持てる．
`Replied(int)`は，整数を1つ持つ値である．

```quint
type Reply = NoReply | Replied(int)
```

## match

`match`は，バリアント型の値によって場合を分ける．
値を持つ場合は，その値に名前を付けて使える．

```text
>>> type Reply = NoReply | Replied(int)
>>> Replied(3)
Replied(3)
>>> match Replied(3) { | NoReply => 0 | Replied(n) => n * 10 }
30
>>> match NoReply { | NoReply => 0 | Replied(n) => n * 10 }
0
```

アクションの中でも使える．それぞれの場合に，状態変数の次の値を`all { ... }`で書く．

```quint
action handle = all {
  reply' = reply,
  match reply {
    | NoReply => all { count' = count }
    | Replied(n) => all { count' = count + n }
  },
}
```

## すべて，いずれか

| 書き方 | 意味 |
| --- | --- |
| `S.forall(x => 条件)` | `S`のすべての要素で条件が成り立つ |
| `S.exists(x => 条件)` | `S`のいずれかの要素で条件が成り立つ |
| `M.keys()` | マップ`M`のキーの集合 |

```text
>>> Set(1, 2, 3).forall(x => x > 0)
true
>>> Set(1, 2, 3).exists(x => x > 2)
true
>>> Map("a" -> 1, "b" -> 3).keys().forall(k => Map("a" -> 1, "b" -> 3).get(k) <= 2)
false
```

注文ごとの性質は，`ORDERS.forall(o => ...)`で書く．

## 名前の注意

`item`など，Quintの組み込みの名前は，`match`で付ける名前にも使えない．
使うと，`Built-in name 'item' is redefined`という誤りになる．

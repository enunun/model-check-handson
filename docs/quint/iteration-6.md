# Iteration 6の構文とコマンド

Iteration 6で初めて使う，Quintの構文とコマンドを説明する．
概念の説明は，[抽象化](../concepts/abstraction.md)，[状態爆発と小スコープ仮説](../concepts/state-explosion-and-small-scope.md)にある．

## 状態によらない関数

`pure def 名前(引数: 型): 型 = 式`は，状態変数を読まない関数である．
定数から値を計算するときに使う．
状態変数を読む関数は，これまでどおり`def`で書く．

```text
>>> pure def double(x: int): int = x * 2
>>> double(21)
42
```

## マップのキー

`M.keys()`は，マップ`M`のキーの集合である．
マップどうしは`==`で比べられる．

```text
>>> Map("apple" -> 1, "book" -> 2).keys()
Set("apple", "book")
>>> Map("apple" -> 1) == Map("apple" -> 1)
true
```

マップの値にマップを入れられる．複数行に分けて書ける．

```quint
pure val ORDER_ITEMS = Map(
  "o1" -> Map("apple" -> 1, "book" -> 1),
  "o2" -> Map("book" -> 2),
)
```

## 畳み込み

`S.fold(初期値, (途中の値, 要素) => 式)`は，集合の要素を1つずつ使って値を積み上げる．
合計を求めるときに使う．要素を使う順番は決まっていないので，順番によらない計算(足し算など)に使う．

```text
>>> Set(1, 2, 3).fold(0, (total, x) => total + x)
6
>>> Set("o1", "o2").fold(0, (total, o) => total + Map("o1" -> 1, "o2" -> 2).get(o))
3
```

## TLCで検査するときの注意

TLCで検査するとき，`forall`の中の`fold`に条件式を直接書くと，TLA+への変換で誤りになることがある．
次の誤りが出たら，式を名前付きの`def`に分ける．

```text
Error: Attempted to apply the operator overridden by the Java method
public static tlc2.value.impl.IntValue tlc2.module.Integers.Plus(tlc2.value.impl.IntValue,tlc2.value.impl.IntValue),
but it produced the following error:
Cannot cast tlc2.value.impl.BoolValue to tlc2.value.impl.IntValue
```

```quint
// 注文が引き当てている，商品の個数．
def heldQuantity(order: str, product: str): int =
  if (reservedItems.get(order).contains(product)) quantity(order, product) else 0

// すべての注文が引き当てている，商品の個数の合計．
def totalHeld(product: str): int = ORDERS.fold(0, (total, o) => total + heldQuantity(o, product))
```

## 状態の数を確かめる

`quint verify --backend=tlc`の出力には，調べた状態の数が表示される．

```text
58393 states generated, 2261 distinct states found, 0 states left on queue.
```

定数を変えた仕様の写しを作り，この数と検査の時間を比べる．

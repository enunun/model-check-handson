# Iteration 6：複数商品の注文(解説)

課題の各段階について，模範解答とその考え方を示す．

## 6-1 準備

課題のディレクトリの仕様は，Iteration 5の模範解答と同じなので，検査を通る．

## 6-2 基礎知識と構文

```text
>>> Set(3, 5, 7).fold(1, (product, x) => product * x)
105
>>> pure def square(x: int): int = x * x
>>> Set(1, 2).map(x => square(x))
Set(1, 4)
```

積を求めるときは，初期値を`1`にする．

## 6-3 シナリオのテスト

定数と関数は次のとおりである．

```quint
  // 商品．
  pure val ITEMS = Set("apple", "book")
  // 商品ごとの，はじめの在庫数．
  pure val INITIAL_STOCK = Map("apple" -> 1, "book" -> 2)
  // 注文．顧客ごとに1件ずつ注文する．
  pure val ORDERS = Set("o1", "o2")
  // 注文ごとの，商品と個数．
  pure val ORDER_ITEMS = Map(
    "o1" -> Map("apple" -> 1, "book" -> 1),
    "o2" -> Map("book" -> 2),
  )

  // 注文に含まれる商品．
  pure def itemsOf(order: str): Set[str] = ORDER_ITEMS.get(order).keys()
  // 注文に含まれる商品の個数．含まれない商品は0個．
  pure def quantity(order: str, product: str): int =
    if (itemsOf(order).contains(product)) ORDER_ITEMS.get(order).get(product) else 0
```

状態変数`stock`を商品ごとの在庫数にし，引き当てた商品を`reservedItems`に記録する．

```quint
  // 商品ごとの在庫数．
  var stock: str -> int
  // 注文ごとの，引き当てた商品．
  var reservedItems: str -> Set[str]
```

在庫を戻すアクションで使う関数を定義する．

```quint
  // 注文が引き当てた商品を在庫に戻したときの，商品ごとの在庫数．
  def released(order: str): str -> int =
    ITEMS.mapBy(i => stock.get(i) + (if (reservedItems.get(order).contains(i)) quantity(order, i) else 0))
```

在庫の確認と引当は，商品ごとに行う．
すべての商品を引き当てたら，`reserve`で決済を依頼する．

```quint
  // 注文に含まれるすべての商品について，在庫があることを確かめる．
  action checkStock(order: str): bool = all {
    orderStatus.get(order) == NotPlaced,
    itemsOf(order).forall(i => stock.get(i) >= quantity(order, i)),
    stock' = stock,
    reservedItems' = reservedItems,
    orderStatus' = orderStatus.set(order, Checked),
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = shipment,
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
  }

  // 引当の時点でも在庫があれば，注文に含まれる商品を1種類引き当てる．
  action reserveItem(order: str, product: str): bool = all {
    orderStatus.get(order) == Checked,
    itemsOf(order).contains(product),
    not(reservedItems.get(order).contains(product)),
    stock.get(product) >= quantity(order, product),
    stock' = stock.set(product, stock.get(product) - quantity(order, product)),
    reservedItems' = reservedItems.set(order, reservedItems.get(order).union(Set(product))),
    orderStatus' = orderStatus,
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = shipment,
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
  }

  // すべての商品を引き当てたら，決済代行サービスに決済を依頼する．
  action reserve(order: str): bool = all {
    orderStatus.get(order) == Checked,
    reservedItems.get(order) == itemsOf(order),
    stock' = stock,
    reservedItems' = reservedItems,
    orderStatus' = orderStatus.set(order, AwaitingPayment),
    attempts' = attempts.set(order, 1),
    requests' = requests.set(order, requests.get(order) + 1),
    charges' = charges,
    refunds' = refunds,
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = shipment,
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
  }
```

既存のテストは，`reserve("o1")`の前に`reserveItem("o1", "apple")`と`reserveItem("o1", "book")`を加え，在庫の期待値を`stock.get("apple")`で書き直す．
要求文の例は，在庫全体をマップで比べる．

```quint
  // りんご1個と本1冊の注文を受け付けると，りんごの在庫は0個，本の在庫は1冊になる．
  run placeOneOrderTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .expect(stock == Map("apple" -> 0, "book" -> 1) and orderStatus.get("o1") == AwaitingPayment)
```

```text
$ quint test shop_test.qnt
...
  15 passing (836ms)
```

## 6-4 性質

在庫の性質を商品ごとに書き直す．
`invStockConsistent`は，TLCで検査できるように，引き当てている個数の計算を`def`に分ける([Iteration 6の構文とコマンド](../../../../docs/quint/iteration-6.md)の「TLCで検査するときの注意」)．

```quint
  // 在庫は負にならない．
  val invStockNonNegative = ITEMS.forall(i => stock.get(i) >= 0)

  // 注文が引き当てている，商品の個数．
  def heldQuantity(order: str, product: str): int =
    if (reservedItems.get(order).contains(product)) quantity(order, product) else 0

  // すべての注文が引き当てている，商品の個数の合計．
  def totalHeld(product: str): int = ORDERS.fold(0, (total, o) => total + heldQuantity(o, product))

  // 商品ごとに，注文が引き当てている個数と，残りの在庫数の合計は，はじめの在庫数に等しい．
  val invStockConsistent = ITEMS.forall(p => stock.get(p) + totalHeld(p) == INITIAL_STOCK.get(p))
```

引当をしていない注文は，商品を引き当てていないはずである．

```quint
  // 引当をしていない注文(未注文，お断り，決済の失敗，時間切れ，キャンセル済み)は，商品を引き当てていない．
  val invReservedOnlyWhileHolding =
    ORDERS.forall(o =>
      Set(NotPlaced, Rejected, PaymentFailed, Expired, Cancelled).contains(orderStatus.get(o))
        implies reservedItems.get(o) == Set())
```

## 6-5 検査と反例

最後の3つの状態を示す．

```text
$ quint verify shop.qnt --invariants invReservedOnlyWhileHolding --apalache-config=../../../tools/apalache.json
...
[State 3]
{
  attempts: Map("o1" -> 0, "o2" -> 0),
  cancelRequests: Set(),
  charges: Map("o1" -> 0, "o2" -> 0),
  dispatchNotices: Set(),
  notifications: Set(),
  orderStatus: Map("o1" -> Checked, "o2" -> Checked),
  paymentRecord: Map("o1" -> NotProcessed, "o2" -> NotProcessed),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 0),
  reservedItems: Map("o1" -> Set("apple"), "o2" -> Set()),
  shipment: Map("o1" -> NotInstructed, "o2" -> NotInstructed),
  stock: Map("apple" -> 0, "book" -> 2),
  withdrawNotices: Set()
}

[State 4]
{
  attempts: Map("o1" -> 0, "o2" -> 0),
  cancelRequests: Set(),
  charges: Map("o1" -> 0, "o2" -> 0),
  dispatchNotices: Set(),
  notifications: Set(),
  orderStatus: Map("o1" -> Checked, "o2" -> Checked),
  paymentRecord: Map("o1" -> NotProcessed, "o2" -> NotProcessed),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 0),
  reservedItems: Map("o1" -> Set("apple"), "o2" -> Set("book")),
  shipment: Map("o1" -> NotInstructed, "o2" -> NotInstructed),
  stock: Map("apple" -> 0, "book" -> 0),
  withdrawNotices: Set()
}

[State 5]
{
  attempts: Map("o1" -> 0, "o2" -> 0),
  cancelRequests: Set(),
  charges: Map("o1" -> 0, "o2" -> 0),
  dispatchNotices: Set(),
  notifications: Set(),
  orderStatus: Map("o1" -> Rejected, "o2" -> Checked),
  paymentRecord: Map("o1" -> NotProcessed, "o2" -> NotProcessed),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 0),
  reservedItems: Map("o1" -> Set("apple"), "o2" -> Set("book")),
  shipment: Map("o1" -> NotInstructed, "o2" -> NotInstructed),
  stock: Map("apple" -> 0, "book" -> 0),
  withdrawNotices: Set()
}

[violation] Found an issue (10897ms).
error: found a counterexample
```

問いへの答えは次のとおりである．

1. 注文`o1`が`Rejected`なのに，りんごを引き当てたままになっている．りんごの在庫は0個のままで，ほかの注文はりんごを買えない．
2. `o1`がりんごを引き当てたあと，`o2`が本を2冊引き当て，本の在庫がなくなった．`o1`は本を引き当てられないので断られた．
3. 要求文は商品ごとに引き当てると書くが，一部の商品だけ引き当てた注文を断るとき，引き当てた商品をどうするかを決めていない．

`invStockConsistent`は，この反例でも成り立つ．
在庫の数え方は正しく，りんごは`o1`が引き当てているものとして数えられているからである．
在庫の数は合っていても，断った注文がりんごを持ち続ければ，誰も買えない在庫が残る．

## 6-6 決定と反映

注文単位で，すべての商品を引き当てるか，すべて断ると決める．
断るときは，引き当てた商品を在庫に戻す．

```markdown
### Iteration 6

- 注文単位で，すべての商品を引き当てるか，すべて断る．引当の途中で在庫の足りない商品が見つかれば，引き当てた商品を在庫に戻してから断る．(性質：invReservedOnlyWhileHolding)
```

```quint
  // 在庫が足りない商品があれば，確認の前でも後でも注文を断る．
  // 引当の途中なら，引き当てた商品を在庫に戻してから断る．
  action rejectOrder(order: str): bool = all {
    Set(NotPlaced, Checked).contains(orderStatus.get(order)),
    itemsOf(order).exists(i => not(reservedItems.get(order).contains(i)) and stock.get(i) < quantity(order, i)),
    stock' = released(order),
    reservedItems' = reservedItems.set(order, Set()),
    orderStatus' = orderStatus.set(order, Rejected),
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = shipment,
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
  }
```

反例の手順で，りんごが在庫に戻ることをテストで確かめる．

```quint
  // 引当の途中で本の在庫が足りなくなったら，引き当てたりんごを在庫に戻してから，注文を断る．
  run releaseOnPartialRejectTest =
    init
      .then(checkStock("o1"))
      .then(checkStock("o2"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o2", "book"))
      .then(rejectOrder("o1"))
      .expect(orderStatus.get("o1") == Rejected and stock == Map("apple" -> 1, "book" -> 0))
```

状態遷移図はIteration 5から変わらない．
引当の途中の状態は`Checked`のままで，商品ごとの引当は注文の状態を変えないからである．

```text
$ mise run verify iterations/iteration-6/exercise
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 1h ago)
Lockfile is up to date, resolution step is skipped
Done in 20ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-6/exercise
ok  Quintの評価器とApalache

iterations/iteration-6/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  quint verify(時相論理の性質)
ok  状態遷移図
Finished in 28.55s
```

## 6-7 振り返り

1. 模範解答は「すべて引き当てるか，すべて断る」である．「引き当てられた商品だけで注文を受け付ける」と決めることもできる．その場合は，注文の中身が変わることを顧客に確かめる必要がある．
2. 模範解答の仕様で，定数を変えたときの状態の数と検査の時間は次のとおりである．

   | 定数 | 状態の数 | 検査の時間 |
   | --- | --- | --- |
   | 模範解答(注文2件，再試行の上限2回) | 2,261 | 約8秒 |
   | 再試行の上限3回 | 7,792 | 約8秒 |
   | 注文`o3`を加え，りんごの在庫を2個 | 131,138 | 約22秒 |

   注文を1件増やすと，状態の数は約58倍になった．
3. 時間(具体的な時刻)，決済代行サービスと配送システムの内部の処理，顧客と注文と商品の数，再試行の回数を省いてきた．
   たとえば，時間切れまでの長さを省いたので，「時間切れが短すぎて，ほとんどの注文が時間切れになる」といった問題は調べていない．
4. 6-5の反例は，注文2件で起きる．りんごを持つ注文と，本を取り合う注文があればよい．
   大きな定数で検査すると，2件では起きない組み合わせを調べられるが，時間がかかる．小さな定数で誤りを直してから，余裕があれば大きくする．

## 6-8 発展課題

在庫の確認と引当を注文単位で1回に行うと，`reserveItem`と`reservedItems`が不要になり，状態の数は減る．
引当の途中の状態がなくなるので，6-5の問題は起きない．
その代わりに，実装では複数の商品の在庫を1つのトランザクションで更新する必要がある．
商品ごとに在庫を管理するシステムが分かれている場合は，それができないので，6-6のように戻す処理が必要になる．

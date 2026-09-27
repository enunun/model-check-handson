# Iteration 3：決済の再試行と通知の重複(解説)

課題の各段階について，模範解答とその考え方を示す．

## 3-1 準備

課題のディレクトリの仕様は，Iteration 2の模範解答と同じなので，検査を通る．

## 3-2 基礎知識と構文

REPLの課題の答えを示す．

```text
>>> type Box = Empty | Full(str)
>>> match Full("apple") { | Empty => "nothing" | Full(fruit) => fruit }
"apple"
>>> Set(2, 4, 6).forall(x => x % 2 == 0)
true
>>> Set(1, 2, 3).exists(x => x > 3)
false
```

`match`で付ける名前に`item`を使うと，組み込みの名前と重なって誤りになる．

## 3-3 シナリオのテスト

課金と返金を回数で数え，再試行を`retryPayment`として加える．
`processPayment`は，依頼ごとに決済する．
`receiveNotification`は通知を集合から取り除かないので，同じ通知を何回でも受け取れる．
3-4の不変条件も含めた仕様を示す．

```quint
// ECショップの注文処理の仕様．
module shop {
  // 注文の状態．
  type OrderStatus =
    | NotPlaced
    | Checked
    | AwaitingPayment
    | Confirmed
    | PaymentFailed
    | Expired
    | Rejected
  // 決済の結果．
  type PaymentResult = Success | Failure

  // はじめの在庫数．
  pure val INITIAL_STOCK = 1
  // 注文．顧客ごとに1件ずつ注文する．
  pure val ORDERS = Set("o1", "o2")
  // 1件の注文について，決済を依頼する回数の上限(最初の依頼と再試行の合計)．
  pure val MAX_ATTEMPTS = 2

  // 在庫数．
  var stock: int
  // 注文ごとの状態．
  var orderStatus: str -> OrderStatus
  // 注文ごとの，決済を依頼した回数．
  var attempts: str -> int
  // 注文ごとの，決済代行サービスがまだ処理していない依頼の数．
  var requests: str -> int
  // 注文ごとの，決済代行サービスが課金した回数．
  var charges: str -> int
  // 注文ごとの，返金した回数．
  var refunds: str -> int
  // 決済代行サービスが送った通知．同じ通知は，受け取ったあとも再び届きうる．
  var notifications: Set[(str, PaymentResult)]

  action init = all {
    stock' = INITIAL_STOCK,
    orderStatus' = ORDERS.mapBy(_ => NotPlaced),
    attempts' = ORDERS.mapBy(_ => 0),
    requests' = ORDERS.mapBy(_ => 0),
    charges' = ORDERS.mapBy(_ => 0),
    refunds' = ORDERS.mapBy(_ => 0),
    notifications' = Set(),
  }

  // 在庫があることを確かめる．
  action checkStock(order: str): bool = all {
    orderStatus.get(order) == NotPlaced,
    stock > 0,
    stock' = stock,
    orderStatus' = orderStatus.set(order, Checked),
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    notifications' = notifications,
  }

  // 引当の時点でも在庫があれば，在庫を1個引き当て，決済代行サービスに決済を依頼する．
  action reserve(order: str): bool = all {
    orderStatus.get(order) == Checked,
    stock > 0,
    stock' = stock - 1,
    orderStatus' = orderStatus.set(order, AwaitingPayment),
    attempts' = attempts.set(order, 1),
    requests' = requests.set(order, requests.get(order) + 1),
    charges' = charges,
    refunds' = refunds,
    notifications' = notifications,
  }

  // 在庫がなければ，確認の前でも後でも注文を断る．
  action rejectOrder(order: str): bool = all {
    Set(NotPlaced, Checked).contains(orderStatus.get(order)),
    stock == 0,
    stock' = stock,
    orderStatus' = orderStatus.set(order, Rejected),
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    notifications' = notifications,
  }

  // 決済の結果が届かない注文について，決済を再び依頼する．
  action retryPayment(order: str): bool = all {
    orderStatus.get(order) == AwaitingPayment,
    attempts.get(order) < MAX_ATTEMPTS,
    stock' = stock,
    orderStatus' = orderStatus,
    attempts' = attempts.set(order, attempts.get(order) + 1),
    requests' = requests.set(order, requests.get(order) + 1),
    charges' = charges,
    refunds' = refunds,
    notifications' = notifications,
  }

  // 決済代行サービスが依頼を1つ処理し，成功なら課金して，結果を通知する．
  action processPayment(order: str, result: PaymentResult): bool = all {
    requests.get(order) > 0,
    stock' = stock,
    orderStatus' = orderStatus,
    attempts' = attempts,
    requests' = requests.set(order, requests.get(order) - 1),
    charges' = if (result == Success) charges.set(order, charges.get(order) + 1) else charges,
    refunds' = refunds,
    notifications' = notifications.union(Set((order, result))),
  }

  // 決済の結果の通知を受け取る．
  // 決済待ちの注文は，成功なら確定し，失敗なら引当を解除する．
  // 時間切れになった注文は，成功なら返金し，失敗なら何もしない．
  action receiveNotification(order: str, result: PaymentResult): bool = all {
    notifications.contains((order, result)),
    notifications' = notifications,
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    if (orderStatus.get(order) == AwaitingPayment and result == Success) all {
      stock' = stock,
      orderStatus' = orderStatus.set(order, Confirmed),
      refunds' = refunds,
    } else if (orderStatus.get(order) == AwaitingPayment and result == Failure) all {
      stock' = stock + 1,
      orderStatus' = orderStatus.set(order, PaymentFailed),
      refunds' = refunds,
    } else if (orderStatus.get(order) == Expired and result == Success) all {
      stock' = stock,
      orderStatus' = orderStatus,
      refunds' = refunds.set(order, refunds.get(order) + 1),
    } else all {
      stock' = stock,
      orderStatus' = orderStatus,
      refunds' = refunds,
    },
  }

  // 時間切れ監視ジョブが，決済の結果が届かない注文の引当を解除する．
  action expire(order: str): bool = all {
    orderStatus.get(order) == AwaitingPayment,
    stock' = stock + 1,
    orderStatus' = orderStatus.set(order, Expired),
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    notifications' = notifications,
  }

  action step = {
    nondet order = ORDERS.oneOf()
    nondet result = Set(Success, Failure).oneOf()
    any {
      checkStock(order),
      reserve(order),
      rejectOrder(order),
      retryPayment(order),
      processPayment(order, result),
      receiveNotification(order, result),
      expire(order),
    }
  }

  // 在庫は負にならない．
  val invStockNonNegative = stock >= 0

  // 決済待ちか確定した注文の数と，残りの在庫数の合計は，はじめの在庫数に等しい．
  val invStockConsistent =
    stock + ORDERS.filter(o => Set(AwaitingPayment, Confirmed).contains(orderStatus.get(o))).size()
      == INITIAL_STOCK

  // 1件の注文に，2回以上課金しない．
  val invChargedAtMostOnce = ORDERS.forall(o => charges.get(o) <= 1)

  // 課金した回数より多く返金しない．
  val invRefundsWithinCharges = ORDERS.forall(o => refunds.get(o) <= charges.get(o))
}
```

返金を確かめていたテストは，決済の状態の代わりに返金の回数を確かめる．

```quint
  // 時間切れのあとに成功の通知が届くと，注文は確定せずに返金する．在庫は1個のままである．
  run refundAfterExpireTest =
    init
      .then(checkStock("o1"))
      .then(reserve("o1"))
      .then(expire("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .expect(stock == 1 and orderStatus.get("o1") == Expired and refunds.get("o1") == 1)
```

要求文の例をテストにする．

```quint
  // 再試行した決済が成功すると，注文は確定する．
  run confirmAfterRetryTest =
    init
      .then(checkStock("o1"))
      .then(reserve("o1"))
      .then(retryPayment("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .expect(orderStatus.get("o1") == Confirmed)
```

```text
$ quint test shop_test.qnt

  shop_test
    ok placeOneOrderTest passed 1 test(s)
    ok rejectWhenOutOfStockTest passed 1 test(s)
    ok rejectAfterCheckTest passed 1 test(s)
    ok confirmOnSuccessTest passed 1 test(s)
    ok releaseOnFailureTest passed 1 test(s)
    ok releaseOnExpireTest passed 1 test(s)
    ok refundAfterExpireTest passed 1 test(s)
    ok ignoreFailureAfterExpireTest passed 1 test(s)
    ok confirmAfterRetryTest passed 1 test(s)

  9 passing (163ms)
```

## 3-4 性質

再試行や重複があっても，顧客から見て守られるべきことは次の2つである．

- 1件の注文に，2回以上課金しない．
- 課金していない分を返金しない(返金の回数は課金の回数を超えない)．

```quint
  // 1件の注文に，2回以上課金しない．
  val invChargedAtMostOnce = ORDERS.forall(o => charges.get(o) <= 1)

  // 課金した回数より多く返金しない．
  val invRefundsWithinCharges = ORDERS.forall(o => refunds.get(o) <= charges.get(o))
```

## 3-5 検査と反例

4つの不変条件をまとめて検査すると，`invChargedAtMostOnce`が破れる．

```text
$ quint verify shop.qnt --invariants invStockNonNegative invStockConsistent invChargedAtMostOnce invRefundsWithinCharges
An example execution:

[State 0]
{
  attempts: Map("o1" -> 0, "o2" -> 0),
  charges: Map("o1" -> 0, "o2" -> 0),
  notifications: Set(),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> NotPlaced),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 0),
  stock: 1
}

[State 1]
{
  attempts: Map("o1" -> 0, "o2" -> 0),
  charges: Map("o1" -> 0, "o2" -> 0),
  notifications: Set(),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> Checked),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 0),
  stock: 1
}

[State 2]
{
  attempts: Map("o1" -> 0, "o2" -> 1),
  charges: Map("o1" -> 0, "o2" -> 0),
  notifications: Set(),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> AwaitingPayment),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 1),
  stock: 0
}

[State 3]
{
  attempts: Map("o1" -> 0, "o2" -> 2),
  charges: Map("o1" -> 0, "o2" -> 0),
  notifications: Set(),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> AwaitingPayment),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 2),
  stock: 0
}

[State 4]
{
  attempts: Map("o1" -> 0, "o2" -> 2),
  charges: Map("o1" -> 0, "o2" -> 1),
  notifications: Set(("o2", Success)),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> AwaitingPayment),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 1),
  stock: 0
}

[State 5]
{
  attempts: Map("o1" -> 0, "o2" -> 2),
  charges: Map("o1" -> 0, "o2" -> 2),
  notifications: Set(("o2", Success)),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> AwaitingPayment),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 0),
  stock: 0
}

[violation] Found an issue (7106ms).
  ❌ invChargedAtMostOnce
error: found a counterexample
```

`invRefundsWithinCharges`だけを検査すると，別の反例が出る．

```text
$ quint verify shop.qnt --invariants invRefundsWithinCharges
An example execution:

[State 0]
{
  attempts: Map("o1" -> 0, "o2" -> 0),
  charges: Map("o1" -> 0, "o2" -> 0),
  notifications: Set(),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> NotPlaced),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 0),
  stock: 1
}

[State 1]
{
  attempts: Map("o1" -> 0, "o2" -> 0),
  charges: Map("o1" -> 0, "o2" -> 0),
  notifications: Set(),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> Checked),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 0),
  stock: 1
}

[State 2]
{
  attempts: Map("o1" -> 0, "o2" -> 1),
  charges: Map("o1" -> 0, "o2" -> 0),
  notifications: Set(),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> AwaitingPayment),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 1),
  stock: 0
}

[State 3]
{
  attempts: Map("o1" -> 0, "o2" -> 1),
  charges: Map("o1" -> 0, "o2" -> 0),
  notifications: Set(),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> Expired),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 1),
  stock: 1
}

[State 4]
{
  attempts: Map("o1" -> 0, "o2" -> 1),
  charges: Map("o1" -> 0, "o2" -> 1),
  notifications: Set(("o2", Success)),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> Expired),
  refunds: Map("o1" -> 0, "o2" -> 0),
  requests: Map("o1" -> 0, "o2" -> 0),
  stock: 1
}

[State 5]
{
  attempts: Map("o1" -> 0, "o2" -> 1),
  charges: Map("o1" -> 0, "o2" -> 1),
  notifications: Set(("o2", Success)),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> Expired),
  refunds: Map("o1" -> 0, "o2" -> 1),
  requests: Map("o1" -> 0, "o2" -> 0),
  stock: 1
}

[State 6]
{
  attempts: Map("o1" -> 0, "o2" -> 1),
  charges: Map("o1" -> 0, "o2" -> 1),
  notifications: Set(("o2", Success)),
  orderStatus: Map("o1" -> NotPlaced, "o2" -> Expired),
  refunds: Map("o1" -> 0, "o2" -> 2),
  requests: Map("o1" -> 0, "o2" -> 0),
  stock: 1
}

[violation] Found an issue (7512ms).
error: found a counterexample
```

問いへの答えは次のとおりである．

- `invChargedAtMostOnce`
  1. 注文`o2`に2回課金している．
  2. 最初の依頼の結果が届く前に再試行し，決済代行サービスが2つの依頼をどちらも処理した．
  3. 要求文は再試行を求めるが，再試行した依頼が2つとも処理された場合に，課金をどうするかを決めていない．
- `invRefundsWithinCharges`
  1. 注文`o2`に1回課金し，2回返金している．
  2. 時間切れのあとに成功の通知を受け取り，同じ通知をもう一度受け取った．
  3. 要求文は通知の重複を述べるが，重複した通知をどう扱うかを決めていない．

## 3-6 決定と反映

二重課金は，ECショップの中だけでは防げない．
応答がないとき，ECショップには，依頼が処理されたかどうかを知る方法がないからである．
そこで，決済代行サービスの冪等キーを使うと決める．
二重返金は，返金の回数を課金の回数までに限ることで防ぐ．

```markdown
### Iteration 3

- 再試行すると，同じ注文の決済の依頼が複数回処理されうる．決済の依頼には注文を表す冪等キーを付け，決済代行サービスは同じキーの依頼を2回目以降は処理し直さず，最初の結果を通知し直す．決済代行サービスが冪等キーに対応していることを前提にする．(性質：invChargedAtMostOnce)
- 同じ通知が複数回届いても，返金は課金した回数を超えて行わない．(性質：invRefundsWithinCharges)
```

決済代行サービスの記録を，値を持つバリアント型`PaymentRecord = NotProcessed | Processed(PaymentResult)`で表し，状態変数`paymentRecord`を加える．
ほかのアクションには`paymentRecord' = paymentRecord`を加える．

```quint
  // 決済代行サービスが依頼を1つ処理する．
  // 注文の依頼を初めて処理するときは，決済を行い，成功なら課金して，結果を通知する．
  // 同じ注文の依頼を処理済みなら，決済を行わず，最初の結果を通知し直す(冪等キー)．
  action processPayment(order: str, result: PaymentResult): bool = all {
    requests.get(order) > 0,
    stock' = stock,
    orderStatus' = orderStatus,
    attempts' = attempts,
    requests' = requests.set(order, requests.get(order) - 1),
    refunds' = refunds,
    match paymentRecord.get(order) {
      | NotProcessed => all {
        paymentRecord' = paymentRecord.set(order, Processed(result)),
        charges' = if (result == Success) charges.set(order, charges.get(order) + 1) else charges,
        notifications' = notifications.union(Set((order, result))),
      }
      | Processed(previous) => all {
        paymentRecord' = paymentRecord,
        charges' = charges,
        notifications' = notifications.union(Set((order, previous))),
      }
    },
  }
```

`receiveNotification`では，時間切れの注文への返金に，返金の回数が課金の回数より少ないという条件を加える．

```quint
    } else if (orderStatus.get(order) == Expired and result == Success and refunds.get(order) < charges.get(order)) all {
```

決めた振る舞いを確かめるテストを加える．

```quint
  // 再試行した依頼が2つとも処理されても，課金は1回で，2つ目の依頼には最初の結果が通知される．
  run chargeOnceOnRetryTest =
    init
      .then(checkStock("o1"))
      .then(reserve("o1"))
      .then(retryPayment("o1"))
      .then(processPayment("o1", Success))
      .then(processPayment("o1", Failure))
      .expect(charges.get("o1") == 1 and notifications == Set(("o1", Success)))

  // 時間切れのあとに同じ成功の通知が2回届いても，返金は1回である．
  run refundOnceOnDuplicateTest =
    init
      .then(checkStock("o1"))
      .then(reserve("o1"))
      .then(expire("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .then(receiveNotification("o1", Success))
      .expect(refunds.get("o1") == 1)
```

状態遷移図はIteration 2から変わらない．
再試行や課金は注文の状態を変えないので，図には現れない．

```text
$ mise run verify iterations/iteration-3/exercise
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 30m ago)
Lockfile is up to date, resolution step is skipped
Done in 26ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-3/exercise
ok  Quintの評価器とApalache

iterations/iteration-3/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  状態遷移図
Finished in 77.93s
```

## 3-7 振り返り

1. 返金の回数を限る決定は，ECショップの中だけで実現できる．二重課金を防ぐ決定は，決済代行サービスの冪等キーに頼る．
   外部システムに頼る決定は，その外部システムのAPI仕様で約束されているかを必ず確かめる．約束されていなければ，3-8のような別の決定が必要になる．
2. 3-3のテストには，再試行した依頼が1つだけ処理される手順しかなかった．2つとも処理される手順は，「応答がないのは依頼が届かなかったからとは限らない」と気づいて初めて書ける．
3. 状態遷移図は変わらなかった．誤りは課金と返金の回数にあり，注文の状態には現れなかった．回数の誤りは，不変条件で見つけた．

## 3-8 発展課題

決済代行サービスが冪等キーに対応していない場合は，二重課金が起きうることを受け入れ，課金された分を返金して帳尻を合わせる．
たとえば，確定した注文に2回目の成功の通知が届いたら，その分を返金する．
この場合，不変条件は「課金の回数と返金の回数の差は1以下」のように書き直す．
二重課金が一時的に起きることは，顧客への説明が必要になるので，要求文の決定事項として明記する．

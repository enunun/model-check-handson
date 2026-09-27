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
  // 決済代行サービスでの決済の状態．
  type PaymentStatus = NotRequested | Requested | Succeeded | Failed | Refunded
  // 決済の結果．
  type PaymentResult = Success | Failure

  // はじめの在庫数．
  pure val INITIAL_STOCK = 1
  // 注文．顧客ごとに1件ずつ注文する．
  pure val ORDERS = Set("o1", "o2")

  // 在庫数．
  var stock: int
  // 注文ごとの状態．
  var orderStatus: str -> OrderStatus
  // 注文ごとの，決済代行サービスでの決済の状態．
  var payment: str -> PaymentStatus
  // 決済代行サービスが送り，まだECショップが受け取っていない通知．
  var notifications: Set[(str, PaymentResult)]

  action init = all {
    stock' = INITIAL_STOCK,
    orderStatus' = ORDERS.mapBy(_ => NotPlaced),
    payment' = ORDERS.mapBy(_ => NotRequested),
    notifications' = Set(),
  }

  // 在庫があることを確かめる．
  action checkStock(order: str): bool = all {
    orderStatus.get(order) == NotPlaced,
    stock > 0,
    stock' = stock,
    orderStatus' = orderStatus.set(order, Checked),
    payment' = payment,
    notifications' = notifications,
  }

  // 引当の時点でも在庫があれば，在庫を1個引き当て，決済代行サービスに決済を依頼する．
  action reserve(order: str): bool = all {
    orderStatus.get(order) == Checked,
    stock > 0,
    stock' = stock - 1,
    orderStatus' = orderStatus.set(order, AwaitingPayment),
    payment' = payment.set(order, Requested),
    notifications' = notifications,
  }

  // 在庫がなければ，確認の前でも後でも注文を断る．
  action rejectOrder(order: str): bool = all {
    Set(NotPlaced, Checked).contains(orderStatus.get(order)),
    stock == 0,
    stock' = stock,
    orderStatus' = orderStatus.set(order, Rejected),
    payment' = payment,
    notifications' = notifications,
  }

  // 決済代行サービスが決済を行い，結果を通知する．
  action processPayment(order: str, result: PaymentResult): bool = all {
    payment.get(order) == Requested,
    stock' = stock,
    orderStatus' = orderStatus,
    payment' = payment.set(order, if (result == Success) Succeeded else Failed),
    notifications' = notifications.union(Set((order, result))),
  }

  // 決済の結果の通知を受け取る．
  // 決済待ちの注文は，成功なら確定し，失敗なら引当を解除する．
  // 時間切れになった注文は，成功なら返金し，失敗なら何もしない．
  action receiveNotification(order: str, result: PaymentResult): bool = all {
    notifications.contains((order, result)),
    notifications' = notifications.exclude(Set((order, result))),
    if (orderStatus.get(order) == AwaitingPayment and result == Success) all {
      stock' = stock,
      orderStatus' = orderStatus.set(order, Confirmed),
      payment' = payment,
    } else if (orderStatus.get(order) == AwaitingPayment and result == Failure) all {
      stock' = stock + 1,
      orderStatus' = orderStatus.set(order, PaymentFailed),
      payment' = payment,
    } else if (orderStatus.get(order) == Expired and result == Success) all {
      stock' = stock,
      orderStatus' = orderStatus,
      payment' = payment.set(order, Refunded),
    } else all {
      stock' = stock,
      orderStatus' = orderStatus,
      payment' = payment,
    },
  }

  // 時間切れ監視ジョブが，決済の結果が届かない注文の引当を解除する．
  action expire(order: str): bool = all {
    orderStatus.get(order) == AwaitingPayment,
    stock' = stock + 1,
    orderStatus' = orderStatus.set(order, Expired),
    payment' = payment,
    notifications' = notifications,
  }

  action step = {
    nondet order = ORDERS.oneOf()
    nondet result = Set(Success, Failure).oneOf()
    any {
      checkStock(order),
      reserve(order),
      rejectOrder(order),
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
}

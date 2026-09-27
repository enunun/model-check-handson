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
  // 決済代行サービスが，注文ごとに記録している処理の結果．
  type PaymentRecord = NotProcessed | Processed(PaymentResult)

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
  // 注文ごとの，決済代行サービスの処理の記録．
  var paymentRecord: str -> PaymentRecord
  // 決済代行サービスが送った通知．同じ通知は，受け取ったあとも再び届きうる．
  var notifications: Set[(str, PaymentResult)]

  action init = all {
    stock' = INITIAL_STOCK,
    orderStatus' = ORDERS.mapBy(_ => NotPlaced),
    attempts' = ORDERS.mapBy(_ => 0),
    requests' = ORDERS.mapBy(_ => 0),
    charges' = ORDERS.mapBy(_ => 0),
    refunds' = ORDERS.mapBy(_ => 0),
    paymentRecord' = ORDERS.mapBy(_ => NotProcessed),
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
    paymentRecord' = paymentRecord,
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
    paymentRecord' = paymentRecord,
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
    paymentRecord' = paymentRecord,
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
    paymentRecord' = paymentRecord,
    notifications' = notifications,
  }

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

  // 決済の結果の通知を受け取る．
  // 決済待ちの注文は，成功なら確定し，失敗なら引当を解除する．
  // 時間切れになった注文は，成功ならまだ返金していない分だけ返金し，失敗なら何もしない．
  action receiveNotification(order: str, result: PaymentResult): bool = all {
    notifications.contains((order, result)),
    notifications' = notifications,
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    paymentRecord' = paymentRecord,
    if (orderStatus.get(order) == AwaitingPayment and result == Success) all {
      stock' = stock,
      orderStatus' = orderStatus.set(order, Confirmed),
      refunds' = refunds,
    } else if (orderStatus.get(order) == AwaitingPayment and result == Failure) all {
      stock' = stock + 1,
      orderStatus' = orderStatus.set(order, PaymentFailed),
      refunds' = refunds,
    } else if (orderStatus.get(order) == Expired and result == Success and refunds.get(order) < charges.get(order)) all {
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
    paymentRecord' = paymentRecord,
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

  // 支払いを済ませ，まだ確定も返金もされていない注文．
  def unsettled(o: str): bool = charges.get(o) > refunds.get(o) and orderStatus.get(o) != Confirmed

  // 状態変数の組．公平性の仮定で使う．
  val vars = (stock, orderStatus, attempts, requests, charges, refunds, paymentRecord, notifications)

  // 時間切れ監視ジョブは，決済待ちの注文があれば，いずれ必ず動く．
  temporal expireIsFair = ORDERS.forall(o => weakFair(expire(o), vars))

  // 決済代行サービスが送った通知は，いずれ必ず受け取られる．
  temporal notificationIsFair =
    ORDERS.forall(o => Set(Success, Failure).forall(r => weakFair(receiveNotification(o, r), vars)))

  // 注文は，いつまでも決済待ちのままにはならない．
  temporal liveNoEndlessAwaiting =
    expireIsFair implies
      ORDERS.forall(o => always(orderStatus.get(o) == AwaitingPayment implies eventually(orderStatus.get(o) != AwaitingPayment)))

  // 支払いを済ませた注文は，いずれ確定するか返金される．
  temporal livePaidOrderSettles =
    (expireIsFair and notificationIsFair) implies
      ORDERS.forall(o => always(unsettled(o) implies eventually(not(unsettled(o)))))
}

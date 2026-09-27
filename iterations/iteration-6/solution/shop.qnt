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
    | ShipRequested
    | Shipped
    | Cancelled
    | CancelRequested
  // 決済の結果．
  type PaymentResult = Success | Failure
  // 決済代行サービスが，注文ごとに記録している処理の結果．
  type PaymentRecord = NotProcessed | Processed(PaymentResult)
  // 配送システムでの出荷の状態．
  type ShipmentStatus = NotInstructed | Instructed | Dispatched | Withdrawn
  // 取消依頼に対する，配送システムの応答．
  type WithdrawResult = WithdrawDone | WithdrawRefused

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
  // 1件の注文について，決済を依頼する回数の上限(最初の依頼と再試行の合計)．
  pure val MAX_ATTEMPTS = 2

  // 商品ごとの在庫数．
  var stock: str -> int
  // 注文ごとの，引き当てた商品．
  var reservedItems: str -> Set[str]
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
  // 注文ごとの，配送システムでの出荷の状態．
  var shipment: str -> ShipmentStatus
  // 配送システムが送った発送の通知．同じ通知は，受け取ったあとも再び届きうる．
  var dispatchNotices: Set[str]
  // ECショップが配送システムに送った取消依頼．
  var cancelRequests: Set[str]
  // 配送システムが送った取消依頼への応答．同じ応答は，受け取ったあとも再び届きうる．
  var withdrawNotices: Set[(str, WithdrawResult)]

  // 注文が引き当てた商品を在庫に戻したときの，商品ごとの在庫数．
  def released(order: str): str -> int =
    ITEMS.mapBy(i => stock.get(i) + (if (reservedItems.get(order).contains(i)) quantity(order, i) else 0))

  action init = all {
    stock' = INITIAL_STOCK,
    reservedItems' = ORDERS.mapBy(_ => Set()),
    orderStatus' = ORDERS.mapBy(_ => NotPlaced),
    attempts' = ORDERS.mapBy(_ => 0),
    requests' = ORDERS.mapBy(_ => 0),
    charges' = ORDERS.mapBy(_ => 0),
    refunds' = ORDERS.mapBy(_ => 0),
    paymentRecord' = ORDERS.mapBy(_ => NotProcessed),
    notifications' = Set(),
    shipment' = ORDERS.mapBy(_ => NotInstructed),
    dispatchNotices' = Set(),
    cancelRequests' = Set(),
    withdrawNotices' = Set(),
  }

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

  // 決済の結果が届かない注文について，決済を再び依頼する．
  action retryPayment(order: str): bool = all {
    orderStatus.get(order) == AwaitingPayment,
    attempts.get(order) < MAX_ATTEMPTS,
    stock' = stock,
    reservedItems' = reservedItems,
    orderStatus' = orderStatus,
    attempts' = attempts.set(order, attempts.get(order) + 1),
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

  // 決済代行サービスが依頼を1つ処理する．
  // 注文の依頼を初めて処理するときは，決済を行い，成功なら課金して，結果を通知する．
  // 同じ注文の依頼を処理済みなら，決済を行わず，最初の結果を通知し直す(冪等キー)．
  action processPayment(order: str, result: PaymentResult): bool = all {
    requests.get(order) > 0,
    stock' = stock,
    reservedItems' = reservedItems,
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
    shipment' = shipment,
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
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
      reservedItems' = reservedItems,
      orderStatus' = orderStatus.set(order, Confirmed),
      refunds' = refunds,
    } else if (orderStatus.get(order) == AwaitingPayment and result == Failure) all {
      stock' = released(order),
      reservedItems' = reservedItems.set(order, Set()),
      orderStatus' = orderStatus.set(order, PaymentFailed),
      refunds' = refunds,
    } else if (orderStatus.get(order) == Expired and result == Success and refunds.get(order) < charges.get(order)) all {
      stock' = stock,
      reservedItems' = reservedItems,
      orderStatus' = orderStatus,
      refunds' = refunds.set(order, refunds.get(order) + 1),
    } else all {
      stock' = stock,
      reservedItems' = reservedItems,
      orderStatus' = orderStatus,
      refunds' = refunds,
    },
    shipment' = shipment,
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
  }

  // 時間切れ監視ジョブが，決済の結果が届かない注文の引当を解除する．
  action expire(order: str): bool = all {
    orderStatus.get(order) == AwaitingPayment,
    stock' = released(order),
    reservedItems' = reservedItems.set(order, Set()),
    orderStatus' = orderStatus.set(order, Expired),
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

  // 出荷連携が，確定した注文の出荷を配送システムに指示する．
  action requestShipment(order: str): bool = all {
    orderStatus.get(order) == Confirmed,
    stock' = stock,
    reservedItems' = reservedItems,
    orderStatus' = orderStatus.set(order, ShipRequested),
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = shipment.set(order, Instructed),
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
  }

  // 配送システムが，指示された商品を発送し，発送を通知する．
  action dispatch(order: str): bool = all {
    shipment.get(order) == Instructed,
    stock' = stock,
    reservedItems' = reservedItems,
    orderStatus' = orderStatus,
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = shipment.set(order, Dispatched),
    dispatchNotices' = dispatchNotices.union(Set(order)),
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
  }

  // 発送の通知を受け取り，出荷を指示した注文を出荷済みにする．
  action receiveDispatchNotice(order: str): bool = all {
    dispatchNotices.contains(order),
    stock' = stock,
    reservedItems' = reservedItems,
    orderStatus' = if (orderStatus.get(order) == ShipRequested) orderStatus.set(order, Shipped) else orderStatus,
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

  // 顧客が，出荷を指示する前の注文をキャンセルする．返金し，在庫を戻す．
  action cancelOrder(order: str): bool = all {
    orderStatus.get(order) == Confirmed,
    stock' = released(order),
    reservedItems' = reservedItems.set(order, Set()),
    orderStatus' = orderStatus.set(order, Cancelled),
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds.set(order, refunds.get(order) + 1),
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = shipment,
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
  }

  // 顧客が，出荷を指示した注文をキャンセルする．配送システムに取消を依頼する．
  action requestCancel(order: str): bool = all {
    orderStatus.get(order) == ShipRequested,
    stock' = stock,
    reservedItems' = reservedItems,
    orderStatus' = orderStatus.set(order, CancelRequested),
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = shipment,
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests.union(Set(order)),
    withdrawNotices' = withdrawNotices,
  }

  // 配送システムが取消依頼を処理する．発送前なら取り消し，発送済みなら断る．
  action withdraw(order: str): bool = all {
    cancelRequests.contains(order),
    Set(Instructed, Dispatched, Withdrawn).contains(shipment.get(order)),
    stock' = stock,
    reservedItems' = reservedItems,
    orderStatus' = orderStatus,
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    refunds' = refunds,
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = if (shipment.get(order) == Dispatched) shipment else shipment.set(order, Withdrawn),
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices.union(Set((order, if (shipment.get(order) == Dispatched) WithdrawRefused else WithdrawDone))),
  }

  // 取消依頼への応答を受け取る．
  // 取り消せたら，注文をキャンセルし，返金して在庫を戻す．
  // 発送済みで取り消せなかったら，注文を出荷済みにする．返金はしない．
  action receiveWithdrawNotice(order: str, result: WithdrawResult): bool = all {
    withdrawNotices.contains((order, result)),
    attempts' = attempts,
    requests' = requests,
    charges' = charges,
    paymentRecord' = paymentRecord,
    notifications' = notifications,
    shipment' = shipment,
    dispatchNotices' = dispatchNotices,
    cancelRequests' = cancelRequests,
    withdrawNotices' = withdrawNotices,
    if (orderStatus.get(order) == CancelRequested and result == WithdrawDone) all {
      stock' = released(order),
      reservedItems' = reservedItems.set(order, Set()),
      orderStatus' = orderStatus.set(order, Cancelled),
      refunds' = refunds.set(order, refunds.get(order) + 1),
    } else if (orderStatus.get(order) == CancelRequested and result == WithdrawRefused) all {
      stock' = stock,
      reservedItems' = reservedItems,
      orderStatus' = orderStatus.set(order, Shipped),
      refunds' = refunds,
    } else all {
      stock' = stock,
      reservedItems' = reservedItems,
      orderStatus' = orderStatus,
      refunds' = refunds,
    },
  }

  action step = {
    nondet order = ORDERS.oneOf()
    nondet result = Set(Success, Failure).oneOf()
    nondet withdrawResult = Set(WithdrawDone, WithdrawRefused).oneOf()
    nondet product = ITEMS.oneOf()
    any {
      checkStock(order),
      reserveItem(order, product),
      reserve(order),
      rejectOrder(order),
      retryPayment(order),
      processPayment(order, result),
      receiveNotification(order, result),
      expire(order),
      requestShipment(order),
      dispatch(order),
      receiveDispatchNotice(order),
      cancelOrder(order),
      requestCancel(order),
      withdraw(order),
      receiveWithdrawNotice(order, withdrawResult),
    }
  }

  // 在庫は負にならない．
  val invStockNonNegative = ITEMS.forall(i => stock.get(i) >= 0)

  // 注文が引き当てている，商品の個数．
  def heldQuantity(order: str, product: str): int =
    if (reservedItems.get(order).contains(product)) quantity(order, product) else 0

  // すべての注文が引き当てている，商品の個数の合計．
  def totalHeld(product: str): int = ORDERS.fold(0, (total, o) => total + heldQuantity(o, product))

  // 商品ごとに，注文が引き当てている個数と，残りの在庫数の合計は，はじめの在庫数に等しい．
  val invStockConsistent = ITEMS.forall(p => stock.get(p) + totalHeld(p) == INITIAL_STOCK.get(p))

  // 1件の注文に，2回以上課金しない．
  val invChargedAtMostOnce = ORDERS.forall(o => charges.get(o) <= 1)

  // 課金した回数より多く返金しない．
  val invRefundsWithinCharges = ORDERS.forall(o => refunds.get(o) <= charges.get(o))

  // 支払いを済ませ，商品を受け取る状態(確定，出荷指示済み，出荷済み)にも，返金された状態にもなっていない注文．
  def unsettled(o: str): bool =
    charges.get(o) > refunds.get(o) and not(Set(Confirmed, ShipRequested, Shipped).contains(orderStatus.get(o)))

  // 状態変数の組．公平性の仮定で使う．
  val vars = (stock, orderStatus, attempts, requests, charges, refunds, paymentRecord, notifications, shipment, dispatchNotices, cancelRequests, withdrawNotices, reservedItems)

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
    (expireIsFair and notificationIsFair and logisticsIsFair) implies
      ORDERS.forall(o => always(unsettled(o) implies eventually(not(unsettled(o)))))

  // 返金した注文の商品は，発送しない．
  val invNoRefundAndDispatch = ORDERS.forall(o => not(refunds.get(o) > 0 and shipment.get(o) == Dispatched))

  // 配送システムは，取消依頼に応答し，その応答と発送の通知はいずれ必ず受け取られる．
  temporal logisticsIsFair =
    ORDERS.forall(o =>
      weakFair(withdraw(o), vars)
        and weakFair(receiveDispatchNotice(o), vars)
        and Set(WithdrawDone, WithdrawRefused).forall(r => weakFair(receiveWithdrawNotice(o, r), vars)))

  // 取消依頼中の注文は，いずれキャンセル済みか出荷済みになる．
  temporal liveCancelRequestSettles =
    logisticsIsFair implies
      ORDERS.forall(o => always(orderStatus.get(o) == CancelRequested implies eventually(Set(Cancelled, Shipped).contains(orderStatus.get(o)))))

  // 配送システムで発送された注文は，いずれECショップでも出荷済みになる．
  temporal liveDispatchedBecomesShipped =
    logisticsIsFair implies
      ORDERS.forall(o => always(shipment.get(o) == Dispatched implies eventually(orderStatus.get(o) == Shipped)))

  // 引当をしていない注文(未注文，お断り，決済の失敗，時間切れ，キャンセル済み)は，商品を引き当てていない．
  val invReservedOnlyWhileHolding =
    ORDERS.forall(o =>
      Set(NotPlaced, Rejected, PaymentFailed, Expired, Cancelled).contains(orderStatus.get(o))
        implies reservedItems.get(o) == Set())
}

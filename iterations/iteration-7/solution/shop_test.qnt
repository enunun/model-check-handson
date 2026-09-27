// 要求文の例をシナリオのテストにしたもの．
module shop_test {
  import shop.* from "./shop"

  // りんご1個と本1冊の注文を受け付けると，りんごの在庫は0個，本の在庫は1冊になる．
  run placeOneOrderTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .expect(stock == Map("apple" -> 0, "book" -> 1) and orderStatus.get("o1") == AwaitingPayment)

  // 在庫が1個のとき，Aさんの注文を受け付けたあと，Bさんの注文は断る．
  run rejectWhenOutOfStockTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(rejectOrder("o2"))
      .expect(stock.get("apple") == 0 and orderStatus.get("o2") == Rejected)

  // 2人が在庫を確かめたあと，先に引き当てた注文だけを受け付け，もう一方は断る．
  run rejectAfterCheckTest =
    init
      .then(checkStock("o1"))
      .then(checkStock("o2"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(rejectOrder("o2"))
      .expect(stock.get("apple") == 0 and orderStatus.get("o2") == Rejected)

  // 決済が成功すると，注文は確定し，在庫は0個のままである．
  run confirmOnSuccessTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .expect(stock.get("apple") == 0 and orderStatus.get("o1") == Confirmed)

  // 決済が失敗すると，引当を解除し，在庫は1個に戻る．
  run releaseOnFailureTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(processPayment("o1", Failure))
      .then(receiveNotification("o1", Failure))
      .expect(stock.get("apple") == 1 and orderStatus.get("o1") == PaymentFailed)

  // 決済の結果が届かないまま時間切れになると，引当を解除し，在庫は1個に戻る．
  run releaseOnExpireTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(expire("o1"))
      .expect(stock.get("apple") == 1 and orderStatus.get("o1") == Expired)

  // 時間切れのあとに成功の通知が届くと，注文は確定せずに返金する．在庫は1個のままである．
  run refundAfterExpireTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(expire("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .expect(stock.get("apple") == 1 and orderStatus.get("o1") == Expired and refunds.get("o1") == 1)

  // 時間切れのあとに失敗の通知が届いても，在庫は1個のままである．
  run ignoreFailureAfterExpireTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(expire("o1"))
      .then(processPayment("o1", Failure))
      .then(receiveNotification("o1", Failure))
      .expect(stock.get("apple") == 1 and orderStatus.get("o1") == Expired)

  // 再試行した決済が成功すると，注文は確定する．
  run confirmAfterRetryTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(retryPayment("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .expect(orderStatus.get("o1") == Confirmed)

  // 再試行した依頼が2つとも処理されても，課金は1回で，2つ目の依頼には最初の結果が通知される．
  run chargeOnceOnRetryTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(retryPayment("o1"))
      .then(processPayment("o1", Success))
      .then(processPayment("o1", Failure))
      .expect(charges.get("o1") == 1 and notifications == Set(("o1", Success)))

  // 時間切れのあとに同じ成功の通知が2回届いても，返金は1回である．
  run refundOnceOnDuplicateTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(expire("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .then(receiveNotification("o1", Success))
      .expect(refunds.get("o1") == 1)

  // 確定した注文をキャンセルすると，返金され，在庫は1個に戻る．
  run cancelConfirmedTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .then(cancelOrder("o1"))
      .expect(orderStatus.get("o1") == Cancelled and refunds.get("o1") == 1 and stock.get("apple") == 1)

  // 確定した注文は，出荷を指示され，配送システムが発送すると出荷済みになる．
  run shipConfirmedTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .then(requestShipment("o1"))
      .then(dispatch("o1"))
      .then(receiveDispatchNotice("o1"))
      .expect(orderStatus.get("o1") == Shipped and shipment.get("o1") == Dispatched)

  // 出荷を指示したあとのキャンセルは，配送システムが取り消せたら，返金して在庫を戻す．
  run cancelAfterShipRequestTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .then(requestShipment("o1"))
      .then(requestCancel("o1"))
      .then(withdraw("o1"))
      .then(receiveWithdrawNotice("o1", WithdrawDone))
      .expect(orderStatus.get("o1") == Cancelled and refunds.get("o1") == 1 and shipment.get("o1") == Withdrawn)

  // 取消依頼が届く前に発送されていたら，注文は出荷済みになり，返金しない．
  run cancelTooLateTest =
    init
      .then(checkStock("o1"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o1", "book"))
      .then(reserve("o1"))
      .then(processPayment("o1", Success))
      .then(receiveNotification("o1", Success))
      .then(requestShipment("o1"))
      .then(dispatch("o1"))
      .then(requestCancel("o1"))
      .then(withdraw("o1"))
      .then(receiveWithdrawNotice("o1", WithdrawRefused))
      .expect(orderStatus.get("o1") == Shipped and refunds.get("o1") == 0)

  // 引当の途中で本の在庫が足りなくなったら，引き当てたりんごを在庫に戻してから，注文を断る．
  run releaseOnPartialRejectTest =
    init
      .then(checkStock("o1"))
      .then(checkStock("o2"))
      .then(reserveItem("o1", "apple"))
      .then(reserveItem("o2", "book"))
      .then(rejectOrder("o1"))
      .expect(orderStatus.get("o1") == Rejected and stock == Map("apple" -> 1, "book" -> 0))
}

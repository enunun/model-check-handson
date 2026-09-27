// ECショップの注文処理の仕様．
module shop {
  // 注文の状態．
  type OrderStatus = NotPlaced | Reserved | Rejected

  // はじめの在庫数．
  pure val INITIAL_STOCK = 1

  // 在庫数．
  var stock: int
  // 注文ごとの状態．注文は"o1"と"o2"の2件を考える．
  var orderStatus: str -> OrderStatus

  action init = all {
    stock' = INITIAL_STOCK,
    orderStatus' = Map("o1" -> NotPlaced, "o2" -> NotPlaced),
  }

  // 在庫があれば注文を受け付け，在庫を1個引き当てる．
  action placeOrder(order: str): bool = all {
    orderStatus.get(order) == NotPlaced,
    stock > 0,
    stock' = stock - 1,
    orderStatus' = orderStatus.set(order, Reserved),
  }

  // 在庫がなければ注文を断る．
  action rejectOrder(order: str): bool = all {
    orderStatus.get(order) == NotPlaced,
    stock == 0,
    stock' = stock,
    orderStatus' = orderStatus.set(order, Rejected),
  }

  action step = any {
    placeOrder("o1"),
    placeOrder("o2"),
    rejectOrder("o1"),
    rejectOrder("o2"),
  }

  // 在庫は負にならない．
  val invStockNonNegative = stock >= 0
}

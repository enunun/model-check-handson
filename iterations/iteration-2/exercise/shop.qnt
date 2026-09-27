// ECショップの注文処理の仕様．
module shop {
  // 注文の状態．
  type OrderStatus = NotPlaced | Checked | Reserved | Rejected

  // はじめの在庫数．
  pure val INITIAL_STOCK = 1
  // 注文．顧客ごとに1件ずつ注文する．
  pure val ORDERS = Set("o1", "o2")

  // 在庫数．
  var stock: int
  // 注文ごとの状態．
  var orderStatus: str -> OrderStatus

  action init = all {
    stock' = INITIAL_STOCK,
    orderStatus' = ORDERS.mapBy(_ => NotPlaced),
  }

  // 在庫があることを確かめる．
  action checkStock(order: str): bool = all {
    orderStatus.get(order) == NotPlaced,
    stock > 0,
    stock' = stock,
    orderStatus' = orderStatus.set(order, Checked),
  }

  // 引当の時点でも在庫があれば，在庫を1個引き当てる．
  action reserve(order: str): bool = all {
    orderStatus.get(order) == Checked,
    stock > 0,
    stock' = stock - 1,
    orderStatus' = orderStatus.set(order, Reserved),
  }

  // 在庫がなければ，確認の前でも後でも注文を断る．
  action rejectOrder(order: str): bool = all {
    Set(NotPlaced, Checked).contains(orderStatus.get(order)),
    stock == 0,
    stock' = stock,
    orderStatus' = orderStatus.set(order, Rejected),
  }

  action step = {
    nondet order = ORDERS.oneOf()
    any {
      checkStock(order),
      reserve(order),
      rejectOrder(order),
    }
  }

  // 在庫は負にならない．
  val invStockNonNegative = stock >= 0
}

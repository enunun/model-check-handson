// 要求文の例をシナリオのテストにしたもの．
module shop_test {
  import shop.* from "./shop"

  // 在庫が1個のとき，注文を1件受け付けると在庫は0個になる．
  run placeOneOrderTest =
    init
      .then(placeOrder("o1"))
      .expect(stock == 0 and orderStatus.get("o1") == Reserved)

  // 在庫が0個のとき，注文は断られ，在庫は0個のままである．
  run rejectWhenOutOfStockTest =
    init
      .then(placeOrder("o1"))
      .then(rejectOrder("o2"))
      .expect(stock == 0 and orderStatus.get("o2") == Rejected)
}

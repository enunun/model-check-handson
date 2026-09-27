// 要求文の例をシナリオのテストにしたもの．
module shop_test {
  import shop.* from "./shop"

  // 在庫が1個のとき，注文を1件受け付けると在庫は0個になる．
  run placeOneOrderTest =
    init
      .then(checkStock("o1"))
      .then(reserve("o1"))
      .expect(stock == 0 and orderStatus.get("o1") == Reserved)

  // 在庫が1個のとき，Aさんの注文を受け付けたあと，Bさんの注文は断る．
  run rejectWhenOutOfStockTest =
    init
      .then(checkStock("o1"))
      .then(reserve("o1"))
      .then(rejectOrder("o2"))
      .expect(stock == 0 and orderStatus.get("o2") == Rejected)

  // 2人が在庫を確かめたあと，先に引き当てた注文だけを受け付け，もう一方は断る．
  run rejectAfterCheckTest =
    init
      .then(checkStock("o1"))
      .then(checkStock("o2"))
      .then(reserve("o1"))
      .then(rejectOrder("o2"))
      .expect(stock == 0 and orderStatus.get("o2") == Rejected)
}

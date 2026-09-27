# Iteration 7：仕様から実装のテストを作る(解説)

課題の各段階について，模範解答とその考え方を示す．

## 7-1 準備

課題のディレクトリの仕様は，Iteration 6の模範解答と同じなので，検査を通る．
`impl/`がないので，実装のテストは表示されない．

## 7-2 基礎知識と構文

1. 2つ目の状態のアクションは`checkStock`で，`orderStatus`は`o1`が`Checked`，`o2`が`NotPlaced`である．
   [Iteration 7の構文とコマンド](../../../../docs/quint/iteration-7.md)の例と同じトレースである．
2. `--seed`を変えると，選ばれるアクションと注文が変わり，別のトレースになる．同じ`--seed`なら，同じトレースになる．

## 7-3 実装とトレースのテスト

実装の全体は`impl/src/shop.ts`にある．
状態と設定の型は次のとおりである．

```ts
export type OrderStatus =
  | "NotPlaced"
  | "Checked"
  | "AwaitingPayment"
  | "Confirmed"
  | "PaymentFailed"
  | "Expired"
  | "Rejected"
  | "ShipRequested"
  | "Shipped"
  | "Cancelled"
  | "CancelRequested";

export type PaymentResult = "Success" | "Failure";
export type WithdrawResult = "WithdrawDone" | "WithdrawRefused";

// 商品と注文の設定．
export type Catalog = {
  initialStock: Record<string, number>;
  // 注文ごとの，商品と個数．
  orderItems: Record<string, Record<string, number>>;
  // 1件の注文について，決済を依頼する回数の上限．
  maxAttempts: number;
};

// ECショップが持つ状態．
export type ShopState = {
  stock: Record<string, number>;
  reservedItems: Record<string, string[]>;
  orderStatus: Record<string, OrderStatus>;
  attempts: Record<string, number>;
  refunds: Record<string, number>;
};
```

在庫を戻す処理は，仕様の`released`に対応する．

```ts
// 注文が引き当てた商品を在庫に戻す．
function release(catalog: Catalog, state: ShopState, order: string): ShopState {
  const stock = { ...state.stock };
  for (const product of state.reservedItems[order]) {
    stock[product] += catalog.orderItems[order][product];
  }
  return { ...state, stock, reservedItems: { ...state.reservedItems, [order]: [] } };
}
```

仕様のアクションに対応する関数の例として，`rejectOrder`を示す．
仕様の条件を`ensure`で確かめ，満たさなければ例外にする．

```ts
// 在庫が足りない商品があれば注文を断る．引き当てた商品は在庫に戻す．
export function rejectOrder(catalog: Catalog, state: ShopState, order: string): ShopState {
  ensure(["NotPlaced", "Checked"].includes(state.orderStatus[order]), "断れる状態ではない");
  ensure(
    itemsOf(catalog, order).some(
      (p) => !state.reservedItems[order].includes(p) && state.stock[p] < catalog.orderItems[order][p],
    ),
    "在庫が足りている",
  );
  return withStatus(release(catalog, state, order), order, "Rejected");
}
```

テストの全体は`impl/test/trace.test.ts`にある．
トレースの状態から，ECショップが持つ状態変数を取り出して，実装の状態と同じ形にする．

```ts
// トレースの状態から，ECショップが持つ状態変数を取り出し，実装の状態と同じ形にする．
function expectedState(vars: Record<string, Value>): shop.ShopState {
  const record = <T>(name: string, convert: (v: Value) => T): Record<string, T> =>
    Object.fromEntries([...(vars[name] as Map<Value, Value>)].map(([k, v]) => [String(k), convert(v)]));
  return {
    stock: record("stock", Number),
    reservedItems: record("reservedItems", (v) => [...(v as Set<Value>)].map(String).sort()),
    orderStatus: record("orderStatus", (v) => (v as { tag: shop.OrderStatus }).tag),
    attempts: record("attempts", Number),
    refunds: record("refunds", Number),
  };
}
```

## 7-4 仕様と実装の対応

| 担当 | 状態変数 | アクション |
| --- | --- | --- |
| ECショップ(実装) | `stock`，`reservedItems`，`orderStatus`，`attempts`，`refunds` | `checkStock`，`reserveItem`，`reserve`，`rejectOrder`，`retryPayment`，`receiveNotification`，`expire`，`requestShipment`，`receiveDispatchNotice`，`cancelOrder`，`requestCancel`，`receiveWithdrawNotice` |
| 決済代行サービス | `requests`，`charges`，`paymentRecord`，`notifications` | `processPayment` |
| 配送システム | `shipment`，`dispatchNotices`，`cancelRequests`，`withdrawNotices` | `dispatch`，`withdraw` |

`cancelRequests`と`requests`は，ECショップが送る依頼だが，受け取って処理するのは外部システムなので，環境の側に置いた．

時間切れのあとの成功の通知で返金するかどうかは，決済代行サービスの課金の回数(`charges`)で決まる．
実装では，通知に含まれる課金の情報として，引数`charged`で受け取る．テストでは，トレースの直前の状態の`charges`を渡す．

```ts
// トレースの1ステップを，実装に流す．
// 決済代行サービスと配送システムのアクションは環境なので，ECショップの状態を変えない．
function apply(state: shop.ShopState, step: TraceState, before: TraceState): shop.ShopState {
  const order = String(step.picks.order);
  switch (step.action) {
    case "checkStock":
      return shop.checkStock(catalog, state, order);
    case "reserveItem":
      return shop.reserveItem(catalog, state, order, String(step.picks.product));
    case "reserve":
      return shop.reserve(catalog, state, order);
    case "rejectOrder":
      return shop.rejectOrder(catalog, state, order);
    case "retryPayment":
      return shop.retryPayment(catalog, state, order);
    case "receiveNotification": {
      const charges = before.vars.charges as Map<Value, Value>;
      return shop.receivePaymentNotification(
        catalog,
        state,
        order,
        variant<shop.PaymentResult>(step.picks.result),
        Number(charges.get(order)),
      );
    }
    case "expire":
      return shop.expire(catalog, state, order);
    case "requestShipment":
      return shop.requestShipment(state, order);
    case "receiveDispatchNotice":
      return shop.receiveDispatchNotice(state, order);
    case "cancelOrder":
      return shop.cancelOrder(catalog, state, order);
    case "requestCancel":
      return shop.requestCancel(state, order);
    case "receiveWithdrawNotice":
      return shop.receiveWithdrawNotice(catalog, state, order, variant<shop.WithdrawResult>(step.picks.withdrawResult));
    case "processPayment":
    case "dispatch":
    case "withdraw":
      return state;
    default:
      throw new Error(`実装に対応するアクションがない：${step.action}`);
  }
}
```

## 7-5 検査と不一致

模範解答の実装は，300本のトレースすべてで仕様と一致する．

```text
$ pnpm exec vitest run iterations/iteration-7/solution/impl

 RUN  v5.0.2 /home/user/model-check-handson


 Test Files  1 passed (1)
      Tests  301 passed (301)
   Start at  06:23:45
   Duration  6.54s (import 95%, tests 4%, transform 1%)
```

`rejectOrder`で在庫を戻す処理(`release`)を消すと，42本のトレースで不一致になる．
最初の不一致の内容を示す．

```text
AssertionError: ステップ5(rejectOrder)のあと: expected { Object (stock, reservedItems, ...) } to deeply equal { stock: { apple: 1, book: +0 }, …(4) }

- Expected
+ Received

@@ -10,15 +10,17 @@
    "refunds": {
      "o1": 0,
      "o2": 0,
    },
    "reservedItems": {
-     "o1": [],
+     "o1": [
+       "apple",
+     ],
      "o2": [
        "book",
      ],
    },
    "stock": {
-     "apple": 1,
+     "apple": 0,
      "book": 0,
    },
  }
```

断った注文`o1`が，りんごを引き当てたまま(`reservedItems`に`apple`が残り，りんごの在庫が0個)になっている．
Iteration 6で仕様の抜けとして見つけた誤りが，実装の誤りとしても見つかった．

すべてのアクションがトレースに現れることは，テストで確かめる．
トレースを100本にすると，取消の依頼(`requestCancel`)や取消の応答(`receiveWithdrawNotice`)が1回も現れなかった．
何もしない通知の受け取りが多くのステップを占めるためである．300本にすると，すべてのアクションが現れる．

```ts
describe("仕様のトレースを実装に流す", () => {
  test("実装に流すすべてのアクションが，トレースに現れる", () => {
    const taken = new Set(traces.flatMap((trace) => trace.map((step) => step.action)));
    expect(SHOP_ACTIONS.filter((action) => !taken.has(action))).toEqual([]);
  });

  test.each(traces.map((trace, i) => [i, trace] as const))("トレース%i", (_, trace) => {
    let state = shop.init(catalog);
    expect(state).toEqual(expectedState(trace[0].vars));
    for (let i = 1; i < trace.length; i++) {
      state = apply(state, trace[i], trace[i - 1]);
      expect(state, `ステップ${i}(${trace[i].action})のあと`).toEqual(expectedState(trace[i].vars));
    }
  });
});
```

## 7-6 決定と反映

```markdown
### Iteration 7

- 実装は，仕様の1つのアクションを，割り込まれない1回の操作として行う．1つのアクションで変わる状態は，条件の確認も含めて，1つのトランザクションで変える．
- 実装が仕様どおりに動くことを，仕様から生成したトレースを流すテストで確かめる．
```

```text
$ mise run verify iterations/iteration-7/exercise
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 5m ago)
Lockfile is up to date, resolution step is skipped
Done in 22ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-7/exercise
ok  Quintの評価器とApalache

iterations/iteration-7/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  quint verify(時相論理の性質)
ok  実装のテスト(Vitest)
ok  状態遷移図
Finished in 34.39s
```

## 7-7 振り返り

1. 実装の関数は，仕様のアクションと1対1に対応させた．対応が分かりやすいほど，不一致の原因を探しやすい．
2. 次の誤りは見つからない．
   - 仕様では起きない呼び出しを受け付けてしまう誤り．トレースには，仕様で起きうるアクションしか現れない．たとえば，`cancelOrder`が出荷を指示した注文も受け付けてしまっても，その呼び出しはトレースに現れない．
   - トレースに現れない組み合わせでだけ起きる誤り．
   - HTTPやDBなど，実装の外側の誤り．
3. 1つのアクションを1つのトランザクションにし，条件の確認と更新を同じトランザクションで行う．外部システムへの通信は，トランザクションが確定したあとに行う．
4. 「在庫を引き当てる」「出荷されるまで」「確定」など，要求文の言葉は，状態が増えるたびに意味を決め直した．決め直した結果は，要求文の決定事項と性質として残っている．

## 7-8 発展課題

CIでは，次のどちらかで`mise run check`を実行する．

- コンテナのイメージを使う：`.devcontainer/Dockerfile`でイメージを作り，その中で実行する．開発環境とCIで同じ道具を使える．
- CIの上で道具を入れる：miseで道具を入れ，Quintの評価器とApalacheを`Dockerfile`と同じ手順で`QUINT_HOME`に置く．イメージを作らない分，速い．

どちらでも，Quintの評価器の版とQuint本体の版を合わせる．`mise run check`は，はじめにそれを確かめる．

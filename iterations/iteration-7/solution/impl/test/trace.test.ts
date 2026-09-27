// 仕様(shop.qnt)から生成したトレースを，実装に1ステップずつ流して，状態を比べる．
import path from "node:path";
import { describe, expect, test } from "vitest";
import { generateTraces, type TraceState, type Value } from "../../../../../tools/lib/itf.ts";
import * as shop from "../src/shop.ts";

// 仕様の定数と同じ設定．
const catalog: shop.Catalog = {
  initialStock: { apple: 1, book: 2 },
  orderItems: {
    o1: { apple: 1, book: 1 },
    o2: { book: 2 },
  },
  maxAttempts: 2,
};

// トレースの本数と長さは，すべてのアクションが現れるように選ぶ．
const traces = generateTraces(path.resolve(import.meta.dirname, "../../shop.qnt"), {
  traces: 300,
  maxSteps: 40,
  seed: "1",
});

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

// バリアントの値からタグの名前を取り出す．
function variant<T extends string>(value: Value): T {
  return (value as { tag: string }).tag as T;
}

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

// 実装に流すアクション．環境のアクション(決済代行サービスと配送システム)は含まない．
const SHOP_ACTIONS = [
  "checkStock",
  "reserveItem",
  "reserve",
  "rejectOrder",
  "retryPayment",
  "receiveNotification",
  "expire",
  "requestShipment",
  "receiveDispatchNotice",
  "cancelOrder",
  "requestCancel",
  "receiveWithdrawNotice",
];

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

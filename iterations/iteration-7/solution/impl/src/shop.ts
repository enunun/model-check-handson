// ECショップの注文処理．
// 状態を受け取り，次の状態を返す関数だけで書く．HTTPやDBは扱わない．
// 各関数は1つの操作を割り込まれずに行う前提で書かれている．
// 実際のシステムでは，その前提をDBのトランザクションなどで守る．

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

// 条件を満たさない操作を呼んだときの誤り．
export class RejectedOperation extends Error {}

function ensure(condition: boolean, message: string): void {
  if (!condition) {
    throw new RejectedOperation(message);
  }
}

function orders(catalog: Catalog): string[] {
  return Object.keys(catalog.orderItems);
}

function itemsOf(catalog: Catalog, order: string): string[] {
  return Object.keys(catalog.orderItems[order]);
}

function mapOrders<T>(catalog: Catalog, value: () => T): Record<string, T> {
  return Object.fromEntries(orders(catalog).map((o) => [o, value()]));
}

export function init(catalog: Catalog): ShopState {
  return {
    stock: { ...catalog.initialStock },
    reservedItems: mapOrders(catalog, () => []),
    orderStatus: mapOrders(catalog, (): OrderStatus => "NotPlaced"),
    attempts: mapOrders(catalog, () => 0),
    refunds: mapOrders(catalog, () => 0),
  };
}

function withStatus(state: ShopState, order: string, status: OrderStatus): ShopState {
  return { ...state, orderStatus: { ...state.orderStatus, [order]: status } };
}

// 注文が引き当てた商品を在庫に戻す．
function release(catalog: Catalog, state: ShopState, order: string): ShopState {
  const stock = { ...state.stock };
  for (const product of state.reservedItems[order]) {
    stock[product] += catalog.orderItems[order][product];
  }
  return { ...state, stock, reservedItems: { ...state.reservedItems, [order]: [] } };
}

function refund(state: ShopState, order: string): ShopState {
  return { ...state, refunds: { ...state.refunds, [order]: state.refunds[order] + 1 } };
}

export function checkStock(catalog: Catalog, state: ShopState, order: string): ShopState {
  ensure(state.orderStatus[order] === "NotPlaced", "未注文ではない");
  ensure(
    itemsOf(catalog, order).every((p) => state.stock[p] >= catalog.orderItems[order][p]),
    "在庫が足りない",
  );
  return withStatus(state, order, "Checked");
}

export function reserveItem(catalog: Catalog, state: ShopState, order: string, product: string): ShopState {
  const quantity = catalog.orderItems[order][product];
  ensure(state.orderStatus[order] === "Checked", "在庫を確かめていない");
  ensure(quantity !== undefined, "注文に含まれない商品");
  ensure(!state.reservedItems[order].includes(product), "引当済みの商品");
  ensure(state.stock[product] >= quantity, "在庫が足りない");
  return {
    ...state,
    stock: { ...state.stock, [product]: state.stock[product] - quantity },
    reservedItems: { ...state.reservedItems, [order]: [...state.reservedItems[order], product].sort() },
  };
}

// すべての商品を引き当てた注文について，決済を依頼する．
export function reserve(catalog: Catalog, state: ShopState, order: string): ShopState {
  ensure(state.orderStatus[order] === "Checked", "在庫を確かめていない");
  ensure(
    [...state.reservedItems[order]].sort().join() === itemsOf(catalog, order).sort().join(),
    "引き当てていない商品がある",
  );
  return { ...withStatus(state, order, "AwaitingPayment"), attempts: { ...state.attempts, [order]: 1 } };
}

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

export function retryPayment(catalog: Catalog, state: ShopState, order: string): ShopState {
  ensure(state.orderStatus[order] === "AwaitingPayment", "決済待ちではない");
  ensure(state.attempts[order] < catalog.maxAttempts, "再試行の上限に達した");
  return { ...state, attempts: { ...state.attempts, [order]: state.attempts[order] + 1 } };
}

// 決済の結果の通知を受け取る．charged(課金された回数)は決済代行サービスが持つ値で，返金できる上限になる．
export function receivePaymentNotification(
  catalog: Catalog,
  state: ShopState,
  order: string,
  result: PaymentResult,
  charged: number,
): ShopState {
  const status = state.orderStatus[order];
  if (status === "AwaitingPayment" && result === "Success") {
    return withStatus(state, order, "Confirmed");
  }
  if (status === "AwaitingPayment" && result === "Failure") {
    return withStatus(release(catalog, state, order), order, "PaymentFailed");
  }
  if (status === "Expired" && result === "Success" && state.refunds[order] < charged) {
    return refund(state, order);
  }
  return state;
}

export function expire(catalog: Catalog, state: ShopState, order: string): ShopState {
  ensure(state.orderStatus[order] === "AwaitingPayment", "決済待ちではない");
  return withStatus(release(catalog, state, order), order, "Expired");
}

export function requestShipment(state: ShopState, order: string): ShopState {
  ensure(state.orderStatus[order] === "Confirmed", "確定していない");
  return withStatus(state, order, "ShipRequested");
}

export function receiveDispatchNotice(state: ShopState, order: string): ShopState {
  return state.orderStatus[order] === "ShipRequested" ? withStatus(state, order, "Shipped") : state;
}

export function cancelOrder(catalog: Catalog, state: ShopState, order: string): ShopState {
  ensure(state.orderStatus[order] === "Confirmed", "出荷を指示する前ではない");
  return refund(withStatus(release(catalog, state, order), order, "Cancelled"), order);
}

export function requestCancel(state: ShopState, order: string): ShopState {
  ensure(state.orderStatus[order] === "ShipRequested", "出荷を指示していない");
  return withStatus(state, order, "CancelRequested");
}

export function receiveWithdrawNotice(
  catalog: Catalog,
  state: ShopState,
  order: string,
  result: WithdrawResult,
): ShopState {
  if (state.orderStatus[order] !== "CancelRequested") {
    return state;
  }
  if (result === "WithdrawDone") {
    return refund(withStatus(release(catalog, state, order), order, "Cancelled"), order);
  }
  return withStatus(state, order, "Shipped");
}

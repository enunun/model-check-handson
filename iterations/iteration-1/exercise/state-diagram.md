# 状態遷移図

注文の状態(`orderStatus`)がどのアクションでどう変わるかを示す．
このファイルは，仕様のトレースから`mise run diagram`で生成する．手で編集しない．

```mermaid
stateDiagram-v2
  [*] --> NotPlaced
  NotPlaced --> Rejected : rejectOrder
  NotPlaced --> Reserved : placeOrder
```

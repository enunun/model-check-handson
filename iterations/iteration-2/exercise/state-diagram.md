# 状態遷移図

注文の状態(`orderStatus`)がどのアクションでどう変わるかを示す．
このファイルは，仕様のトレースから`mise run diagram`で生成する．手で編集しない．

```mermaid
stateDiagram-v2
  [*] --> NotPlaced
  Checked --> Rejected : rejectOrder
  Checked --> Reserved : reserve
  NotPlaced --> Checked : checkStock
  NotPlaced --> Rejected : rejectOrder
```

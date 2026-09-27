# 基礎知識

モデル検査で仕様を調べるときに必要な，形式手法の基礎知識をまとめる．
各Iterationを始める前に，そのIterationの概念を読んでおく．

| Iteration | 概念 |
| --- | --- |
| 0 | [状態遷移系](state-transition-system.md)，[不変条件](invariant.md)，[テスト・シミュレーション・モデル検査](testing-and-model-checking.md) |
| 1 | [非決定性](nondeterminism.md)，[インターリーブと原子性](interleaving-and-atomicity.md)，[デッドロック](deadlock.md) |
| 2 | [環境のモデル化](environment-modeling.md)，[非同期メッセージ](async-messaging.md)，[時間の抽象化](time-abstraction.md) |
| 3 | [メッセージの配送保証](delivery-guarantees.md)，[冪等性](idempotency.md) |
| 4 | [安全性と活性](safety-and-liveness.md)，[時相論理](temporal-logic.md)，[公平性](fairness.md)，[有界モデル検査と全状態探索](bounded-and-exhaustive.md) |
| 5 | [結果整合性](eventual-consistency.md)，[補償処理](compensation.md) |

各ファイルには，概念の要点，ECショップとは別の小さな例，テストとの違い，よくある誤解を書いてある．
最後の「Quintでの書き方」から，その概念を書くための構文の解説に進める．

Quintの構文とコマンドは，[Quintの構文とコマンド](../quint/README.md)にまとめてある．

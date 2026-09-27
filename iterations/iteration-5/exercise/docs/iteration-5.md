# Iteration 5：キャンセルと出荷

キャンセルと出荷を仕様に加える．
ECショップと配送システムという2つのシステムが，同じ注文の状態をそれぞれ持つ．
2つのシステムの状態が食い違う間に起きる問題を検査し，食い違いがいずれ解消されることを確かめる．

作業はすべて，このディレクトリ(`iterations/iteration-5/exercise`)で行う．
このディレクトリの仕様とテストは，Iteration 4の模範解答と同じである．

## 5-1 準備

リポジトリの直下で次を実行し，検査が通ることを確かめる．

```sh
mise run verify iterations/iteration-5/exercise
```

```text
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 1h ago)
Lockfile is up to date, resolution step is skipped
Done in 20ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-5/exercise
ok  Quintの評価器とApalache

iterations/iteration-5/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  quint verify(時相論理の性質)
ok  状態遷移図
Finished in 19.25s
```

`requirements.md`の要求に，`### Iteration 5`の要求が加わっている．

## 5-2 基礎知識と構文

次を読む．

- [結果整合性](../../../../docs/concepts/eventual-consistency.md)
- [補償処理](../../../../docs/concepts/compensation.md)
- [Iteration 5の構文とコマンド](../../../../docs/quint/iteration-5.md)

読んだら，次の問いに答える．

1. [結果整合性](../../../../docs/concepts/eventual-consistency.md)の図書館の例で，食い違っている間に守るべき安全性を1つ挙げる．
2. 身近なサービスで，補償処理(取り消す代わりに効果を打ち消す処理)の例を1つ挙げ，それが失敗しうる場合を考える．

## 5-3 シナリオのテスト

Iteration 5で加わった要求文を読む．

- 顧客は，出荷されるまで注文をキャンセルできる．キャンセルした注文は返金する．
- 確定した注文は，出荷連携が配送システムに出荷を指示する．
- 例：確定した注文をキャンセルすると，返金され，在庫は1個に戻る．
- 例：確定した注文は，配送システムが発送すると出荷済みになる．

配送システムは，ECショップの外の環境である．
配送システムの出荷の状態を状態変数にし，発送は配送システムのアクションとして書く．
発送の通知は，決済の通知と同じく，受け取ったあとも再び届きうるメッセージとして書く．
仕様では，次の名前を使う．

| 名前 | 種類 | 内容 |
| --- | --- | --- |
| `ShipRequested`，`Shipped`，`Cancelled` | `OrderStatus`の値 | 出荷を指示した状態，出荷済みの状態，キャンセル済みの状態 |
| `ShipmentStatus` | 型 | 配送システムでの出荷の状態．`NotInstructed`，`Instructed`，`Dispatched` |
| `shipment` | 状態変数 | 注文ごとの，配送システムでの出荷の状態 |
| `dispatchNotices` | 状態変数 | 配送システムが送った発送の通知(注文の集合) |
| `requestShipment(order: str)` | アクション | 確定した注文の出荷を指示する |
| `dispatch(order: str)` | アクション | 配送システムが商品を発送し，通知する |
| `receiveDispatchNotice(order: str)` | アクション | 発送の通知を受け取り，出荷を指示した注文を出荷済みにする |
| `cancelOrder(order: str)` | アクション | 顧客が注文をキャンセルする．返金し，在庫を戻す |

状態変数を加えたら，[Iteration 5の構文とコマンド](../../../../docs/quint/iteration-5.md)の手順に従って，既存のすべてのアクションと`vars`を直す．
要求文の2つの例をテストにする．

## 5-4 性質

まず，新しい性質を加えずに`mise run verify`を実行する．
既存の性質が破れたら，それは仕様の誤りか，性質の定義が新しい状態に追いついていないのかを考え，直す．

次に，キャンセルと出荷について，お金と商品の面で守られるべきことを不変条件として書く．
名前は`invNoRefundAndDispatch`とする．

## 5-5 検査と反例

`invNoRefundAndDispatch`を検査する．

```sh
quint verify shop.qnt --invariants invNoRefundAndDispatch --apalache-config=../../../tools/apalache.json
```

反例が出たら，次の問いに答える．

1. 最後の状態で，ECショップと配送システムの状態はそれぞれ何か．
2. キャンセルと発送は，どの順番で起きたか．
3. 要求文の「出荷されるまで」は，ECショップと配送システムのどちらの状態で判断すると読めるか．

## 5-6 決定と反映

5-5で見つけた抜けについて，振る舞いを決める．
[補償処理](../../../../docs/concepts/compensation.md)の「補償処理を決めるときの問い」を参考にする．

決めた振る舞いを仕様に反映したら，食い違いがいずれ解消されることを，時相論理の性質として書く．

| 名前 | 内容 |
| --- | --- |
| `liveCancelRequestSettles` | 取消を依頼中の注文は，いずれキャンセル済みか出荷済みになる(取消の依頼を加えた場合) |
| `liveDispatchedBecomesShipped` | 配送システムで発送された注文は，いずれECショップでも出荷済みになる |

配送システムの応答や通知について，Iteration 4と同じく公平性を仮定する．
検査して反例が出たら，公平性が足りないのか，振る舞いの抜けなのかを見分けて直す．
最後に，これまでと同じく決定事項，テスト，状態遷移図を更新し，`mise run verify`で検査を通す．

## 5-7 振り返り

1. 自分の決定事項を，模範解答と比べる．取り消せなかった顧客には，何を伝える必要があるか．
2. 5-4で既存の性質が破れたのはなぜか．性質を直すときに，要求文のどの言葉の意味を決め直したか．
3. 5-6で，公平性を仮定しても残った反例は何を意味していたか．
4. 状態遷移図で，`CancelRequested`から出る遷移を確かめる．

## 5-8 発展課題

「出荷を指示したあとのキャンセルは受け付けない」という決定にした場合の仕様を書き，5-6の決定と比べる．
顧客と運用のそれぞれにとって，どちらが望ましいかを考える．

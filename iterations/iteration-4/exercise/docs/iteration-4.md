# Iteration 4：注文が必ず決着する

「いずれ〜する」「いつまでも〜のままにはならない」という要求を，時相論理の性質として書く．
TLCで検査し，処理が途中で止まる実行を見つけ，止まらないために必要な前提を決める．

作業はすべて，このディレクトリ(`iterations/iteration-4/exercise`)で行う．
このディレクトリの仕様とテストは，Iteration 3の模範解答と同じである．

## 4-1 準備

リポジトリの直下で次を実行し，検査が通ることを確かめる．

```sh
mise run verify iterations/iteration-4/exercise
```

```text
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 55m ago)
Lockfile is up to date, resolution step is skipped
Done in 25ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-4/exercise
ok  Quintの評価器とApalache

iterations/iteration-4/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  状態遷移図
Finished in 73.90s
```

`requirements.md`の要求に，`### Iteration 4`の要求が加わっている．

## 4-2 基礎知識と構文

次を読む．

- [安全性と活性](../../../../docs/concepts/safety-and-liveness.md)
- [時相論理](../../../../docs/concepts/temporal-logic.md)
- [公平性](../../../../docs/concepts/fairness.md)
- [有界モデル検査と全状態探索](../../../../docs/concepts/bounded-and-exhaustive.md)
- [Iteration 4の構文とコマンド](../../../../docs/quint/iteration-4.md)

読んだら，[Iteration 4の構文とコマンド](../../../../docs/quint/iteration-4.md)の信号機の仕様を`trafficLight.qnt`として作業用のディレクトリに保存し，次を試す．

1. `liveGreenAfterRed`と`liveGreenAfterRedFair`をTLCで検査し，結果の違いを確かめる．
2. `toYellow`の条件を`light == Red`に変えて，`liveGreenAfterRedFair`を検査する．
   赤から黄にも変われるようになる．反例の最後が`Stuttering`と`Back to state`のどちらかを確かめる．

## 4-3 シナリオのテスト

Iteration 4で加わった要求文を読む．

- 支払いを済ませた注文は，いずれ確定するか返金される．
- 注文は，いつまでも決済待ちのままにはならない．

これらの要求を，`quint test`のテストとして書けるかを考える．
書けるとしたらどんな手順になるか，書けないとしたらなぜかを説明する．

## 4-4 性質

要求文を，時相論理の性質として`shop.qnt`に書く．

| 名前 | 要求文 |
| --- | --- |
| `liveNoEndlessAwaiting` | 注文は，いつまでも決済待ちのままにはならない |
| `livePaidOrderSettles` | 支払いを済ませた注文は，いずれ確定するか返金される |

「支払いを済ませたが，まだ確定と返金のどちらもされていない」ことを，`def unsettled(o: str): bool`として先に定義するとよい．
課金の回数と返金の回数，注文の状態を使う．

## 4-5 検査と反例

性質を1つずつ，TLCで検査する．

```sh
quint verify --backend=tlc shop.qnt --temporal=liveNoEndlessAwaiting
quint verify --backend=tlc shop.qnt --temporal=livePaidOrderSettles
```

反例が出たら，次の問いに答える．

1. 反例の最後の状態で，注文はどの状態か．
2. 反例の最後は`Stuttering`と`Back to state`のどちらか．それは何を意味するか．
3. その状態から，どのアクションが起きれば性質が成り立ったか．そのアクションは，その状態で起きることができたか．
4. 要求文は，そのアクションが起きることについて何を決めていないか．

## 4-6 決定と反映

4-5で見つけた抜けについて，実際のシステムで何を約束するかを決める．
決めた約束を，公平性の仮定として仕様に書き，性質の前提にする．
約束を1つずつ加え，そのたびに検査して，まだ反例が残るかを確かめる．
決めたら，これまでと同じく決定事項を書き，`mise run verify`で検査を通す．

## 4-7 振り返り

1. 自分の決定事項を，模範解答と比べる．公平性として仮定したことを，実際のシステムではどう実現するか．
2. 4-3で，要求文をテストにできたか．テストにできなかったのはなぜか．
3. 公平性の仮定を加えすぎると，何が起きるか．たとえば，決済代行サービスが依頼を必ず処理することを仮定すると，どんな問題を見逃すか．
4. 状態遷移図は，Iteration 3から変わったか．

## 4-8 発展課題

Iteration 2で決めた「時間切れのあとの成功の通知は返金する」を「何もしない」に変えて，`livePaidOrderSettles`を検査する．
反例を読み，返金しないことが何を意味するかを説明する．

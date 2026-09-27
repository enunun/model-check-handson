# Iteration 3：決済の再試行と通知の重複

決済の依頼の再試行と，同じ通知が複数回届くことを仕様にする．
再試行と重複によって，課金や返金が二重に行われないかを検査する．

作業はすべて，このディレクトリ(`iterations/iteration-3/exercise`)で行う．
このディレクトリの仕様とテストは，Iteration 2の模範解答と同じである．

## 3-1 準備

リポジトリの直下で次を実行し，検査が通ることを確かめる．

```sh
mise run verify iterations/iteration-3/exercise
```

```text
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 29m ago)
Lockfile is up to date, resolution step is skipped
Done in 24ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-3/exercise
ok  Quintの評価器とApalache

iterations/iteration-3/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  状態遷移図
Finished in 38.73s
```

`requirements.md`の要求に，`### Iteration 3`の要求が加わっている．

## 3-2 基礎知識と構文

次を読む．

- [メッセージの配送保証](../../../../docs/concepts/delivery-guarantees.md)
- [冪等性](../../../../docs/concepts/idempotency.md)
- [Iteration 3の構文とコマンド](../../../../docs/quint/iteration-3.md)

読んだら，REPLで次を試す．

1. 型`Box`(`Empty`，または文字列を持つ`Full`)を定義し，`Full("apple")`から`match`で中身の文字列を取り出す．
2. `Set(2, 4, 6)`のすべての要素が偶数かを確かめる．`%`は余りを求める演算子である．
3. `Set(1, 2, 3)`に，3より大きい要素があるかを確かめる．

## 3-3 シナリオのテスト

Iteration 3で加わった要求文を読む．

- 決済の依頼に応答がないとき，注文APIは決済を再試行する．
- 決済代行サービスは，同じ結果を複数回通知することがある．
- 例：再試行した決済が成功すると，注文は確定する．

再試行すると，決済代行サービスには同じ注文の依頼が複数届く．
依頼ごとに課金されうるので，課金と返金を「状態」ではなく「回数」で数える．
Iteration 2の`payment`(決済の状態)を，次の状態変数に置き換える．

| 名前 | 種類 | 内容 |
| --- | --- | --- |
| `MAX_ATTEMPTS` | 定数 | 1件の注文について，決済を依頼する回数の上限(最初の依頼と再試行の合計)．`2` |
| `attempts` | 状態変数 | 注文ごとの，決済を依頼した回数 |
| `requests` | 状態変数 | 注文ごとの，決済代行サービスがまだ処理していない依頼の数 |
| `charges` | 状態変数 | 注文ごとの，課金した回数 |
| `refunds` | 状態変数 | 注文ごとの，返金した回数 |
| `retryPayment(order: str)` | アクション | 決済待ちの注文について，決済を再び依頼する |

`processPayment`は，処理していない依頼を1つ処理し，成功なら課金する．
`receiveNotification`は，通知を集合から取り除かない．同じ通知を再び受け取れるようにするためである．

`payment`がなくなるので，Iteration 2のテストのうち，返金を確かめているものの期待値を直す．
そのうえで，要求文の例をテストにする．

## 3-4 性質

再試行と重複について，お金の面で守られるべきことを不変条件として書く．
課金の回数と返金の回数について考える．
名前は`invChargedAtMostOnce`と`invRefundsWithinCharges`とする．

## 3-5 検査と反例

4つの不変条件をまとめて検査する．
反例が出たら，破れた不変条件ごとに，次の問いに答える．

1. 最後の状態で，何が何回起きているか．
2. 再試行や重複は，どの時点で起きたか．
3. 要求文は，その場合の振る舞いについて何を決めていないか．

1つの不変条件だけを検査するには，`--invariants`に1つだけ名前を書く．

## 3-6 決定と反映

3-5で見つけた抜けについて，振る舞いを決める．
決済代行サービス側の振る舞いに頼る決定をするときは，それが外部システムの仕様として約束されていることを前提として書く．
決めたら，これまでと同じく，決定事項，仕様，テスト，状態遷移図を更新し，`mise run verify`で検査を通す．

## 3-7 振り返り

1. 自分の決定事項を，模範解答と比べる．ECショップの中だけで解決できる決定と，外部システムに頼る決定はどれか．
2. 3-3のテストに，再試行した依頼が2つとも処理される手順はあったか．その手順を，要求文を読んだだけで思いつけたか．
3. 状態遷移図は，Iteration 2から変わったか．変わらなかったのはなぜか．図に現れない誤りを，何で見つけたか．

## 3-8 発展課題

決済代行サービスが冪等キーに対応していない場合を考える．
ECショップの中だけで二重課金に対処する決定(たとえば，二重に課金された分を返金する)を考え，仕様と不変条件を書き直す．

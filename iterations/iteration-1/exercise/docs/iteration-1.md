# Iteration 1：複数の顧客が同時に注文する

複数の顧客が同時に注文する場面を仕様にする．
注文APIの処理を「在庫の確認」と「在庫の引当」の2つの手順に分け，手順が交互に進む場合を検査する．

作業はすべて，このディレクトリ(`iterations/iteration-1/exercise`)で行う．
このディレクトリの仕様とテストは，Iteration 0の模範解答と同じである．

## 1-1 準備

リポジトリの直下で次を実行し，検査が通ることを確かめる．

```sh
mise run verify iterations/iteration-1/exercise
```

```text
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 14m ago)
Lockfile is up to date, resolution step is skipped
Done in 23ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-1/exercise
ok  Quintの評価器とApalache

iterations/iteration-1/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  状態遷移図
Finished in 8.36s
```

`requirements.md`の要求に，`### Iteration 1`の要求が加わっている．

## 1-2 基礎知識と構文

次を読む．

- [非決定性](../../../../docs/concepts/nondeterminism.md)
- [インターリーブと原子性](../../../../docs/concepts/interleaving-and-atomicity.md)
- [デッドロック](../../../../docs/concepts/deadlock.md)
- [Iteration 1の構文とコマンド](../../../../docs/quint/iteration-1.md)

読んだら，REPLで次を試す．

1. 集合`Set("a", "b", "c")`の各要素を`false`に対応させるマップを作る．
2. `Set(1, 2, 3)`の各要素に1を足した集合が，`4`を含むかを確かめる．
3. 座席の持ち主を表す状態変数`seat`(文字列．はじめは`"none"`)を定義する．
   `"alice"`と`"bob"`のどちらかが，空いている座席を取るアクション`take`を，`nondet`を使って定義する．
   `init`のあとに`take`を2回入力し，それぞれの結果と，座席の持ち主を確かめる．

## 1-3 シナリオのテスト

Iteration 1で加わった要求文を読む．

- 複数の顧客が同時に注文できる．
- 注文APIは，在庫を確かめてから引き当てる．
- 例：在庫が1個のとき，Aさんの注文を受け付けたあと，Bさんの注文は断る．

注文APIの処理を，在庫の確認と引当の2つのアクションに分ける．
2つの手順は別々に起きる．その間に，ほかの顧客の注文が先に進むこともある．
仕様では，次の名前を使う．

| 名前 | 種類 | 内容 |
| --- | --- | --- |
| `ORDERS` | 定数 | 注文の集合．`"o1"`(Aさん)と`"o2"`(Bさん) |
| `Checked` | `OrderStatus`の値 | 在庫を確かめた状態 |
| `checkStock(order: str)` | アクション | 在庫があることを確かめる．`placeOrder`の代わりの1つ目の手順 |
| `reserve(order: str)` | アクション | 在庫を1個引き当てる．2つ目の手順 |

`step`では，`nondet`で注文を1つ選び，その注文に起きうるアクションを`any`で並べる．
`init`では，`ORDERS`から`orderStatus`を作る．

`placeOrder`がなくなるので，既存のテストの手順が変わる．
既存のテストのうち，どれをどう直すかを先に考えてから直す．
要求文の例(Aさんのあとに，Bさんの注文を断る)がテストで確かめられているかも確認する．

## 1-4 性質

Iteration 0の不変条件は，そのまま使える．
新しい要求によって，守られるべきことが増えたかを考える．

## 1-5 検査と反例

`quint run`を，`--max-samples`を変えて実行する．

```sh
quint run shop.qnt --invariant=invStockNonNegative --max-samples=1 --seed=1
quint run shop.qnt --invariant=invStockNonNegative --max-samples=1000 --seed=1
quint verify shop.qnt --invariants invStockNonNegative
```

反例が出たら，次の問いに答える．

1. 2つの注文の手順は，どの順番で起きたか．AさんとBさんの手順を分けて書き出す．
2. それぞれの注文の手順だけを見ると，おかしなところはあるか．
3. 要求文は，確認と引当の間に起きることについて，何を決めていないか．
4. `--max-samples=1`で反例が見つからなかったのはなぜか．

## 1-6 決定と反映

1-5で見つけた抜けについて，振る舞いを決める．
[インターリーブと原子性](../../../../docs/concepts/interleaving-and-atomicity.md)の「原子性で問題を解く」を参考にする．
決めたら，Iteration 0と同じく，次を行う．

1. `requirements.md`の決定事項に，`### Iteration 1`の見出しを置き，その下に決めた振る舞いと性質名を書く．
2. `shop.qnt`を直す．
3. 決めた振る舞いを確かめるシナリオのテストを加える．
4. `mise run diagram iterations/iteration-1/exercise`で状態遷移図を生成し直し，図を確かめる．
5. `mise run verify iterations/iteration-1/exercise`で，すべての検査が通ることを確かめる．

`quint verify`を直接実行して`reached a deadlock`と表示されたら，最後の状態を確かめる．
すべての注文が最終的な状態なら，[デッドロック](../../../../docs/concepts/deadlock.md)の「このハンズオンでの扱い」のとおり，正常な終わりである．

## 1-7 振り返り

1. 自分の決定事項を，模範解答と比べる．「確認と引当を1つの操作にする」と「引当の時点でもう一度確かめる」のどちらを選んだか．それぞれ，実装にどんな仕組みが必要になるか．
2. 1-3のテストが通ったのに，1-5で反例が出たのはなぜか．
3. 反例を再現するテストを書くとしたら，どんな手順になるか．そのテストを，要求文を読んだだけで思いつけたか．
4. 状態遷移図で，`Checked`からの遷移を確かめる．

## 1-8 発展課題

注文を3件(`"o3"`を加える)，在庫を2個にして検査する．
反例の長さと，`quint verify`にかかる時間がどう変わるかを確かめる．

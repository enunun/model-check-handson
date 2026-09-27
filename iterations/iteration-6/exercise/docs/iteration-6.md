# Iteration 6：複数商品の注文

1件の注文に，複数の商品を複数個ずつ含められるようにする．
在庫を商品ごとに持ち，商品ごとに引き当てる．
一部の商品だけ在庫が足りない場合に起きる問題を検査し，定数の選び方と状態の数の関係を確かめる．

作業はすべて，このディレクトリ(`iterations/iteration-6/exercise`)で行う．
このディレクトリの仕様とテストは，Iteration 5の模範解答と同じである．

## 6-1 準備

リポジトリの直下で次を実行し，検査が通ることを確かめる．

```sh
mise run verify iterations/iteration-6/exercise
```

```text
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 1h ago)
Lockfile is up to date, resolution step is skipped
Done in 23ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-6/exercise
ok  Quintの評価器とApalache

iterations/iteration-6/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  quint verify(時相論理の性質)
ok  状態遷移図
Finished in 25.70s
```

`requirements.md`の要求に，`### Iteration 6`の要求が加わっている．

## 6-2 基礎知識と構文

次を読む．

- [抽象化](../../../../docs/concepts/abstraction.md)
- [状態爆発と小スコープ仮説](../../../../docs/concepts/state-explosion-and-small-scope.md)
- [Iteration 6の構文とコマンド](../../../../docs/quint/iteration-6.md)

読んだら，REPLで次を試す．

1. `Set(3, 5, 7)`のすべての要素の積を，`fold`で求める．
2. 引数を2乗する`pure def square(x: int): int`を定義し，`Set(1, 2)`の各要素を2乗した集合を作る．

## 6-3 シナリオのテスト

Iteration 6で加わった要求文を読む．

- 1件の注文で，複数の商品を，それぞれ複数個注文できる．
- 注文APIは，注文の商品ごとに在庫を確かめ，引き当てる．
- 例：りんご1個と本1冊の注文を受け付けると，りんごの在庫は0個，本の在庫は1冊になる．

商品は2種類(りんご，本)，注文は2件とし，注文の中身は定数で決める．
注文`o1`はりんご1個と本1冊，注文`o2`は本2冊である．はじめの在庫は，りんご1個，本2冊である．
この組み合わせは，2件の注文が本を取り合い，`o1`だけがりんごも必要になるように選んである．
仕様では，次の名前を使う．

| 名前 | 種類 | 内容 |
| --- | --- | --- |
| `ITEMS` | 定数 | 商品の集合．`"apple"`と`"book"` |
| `INITIAL_STOCK` | 定数 | 商品ごとの，はじめの在庫数 |
| `ORDER_ITEMS` | 定数 | 注文ごとの，商品と個数 |
| `itemsOf(order: str)` | `pure def` | 注文に含まれる商品 |
| `quantity(order: str, product: str)` | `pure def` | 注文に含まれる商品の個数．含まれない商品は0個 |
| `stock` | 状態変数 | 商品ごとの在庫数(`str -> int`) |
| `reservedItems` | 状態変数 | 注文ごとの，引き当てた商品(`str -> Set[str]`) |
| `released(order: str)` | `def` | 注文が引き当てた商品を在庫に戻したときの，商品ごとの在庫数 |
| `reserveItem(order: str, product: str)` | アクション | 注文に含まれる商品を1種類引き当てる |
| `reserve(order: str)` | アクション | すべての商品を引き当てた注文について，決済を依頼する |

在庫を戻すアクション(決済の失敗，時間切れ，キャンセル，取消の成功)は，`released(order)`で在庫を戻し，`reservedItems`を空にする．
`item`はQuintの組み込みの名前なので，引数の名前には`product`を使う．

在庫と引当の書き方が変わるので，既存のすべてのテストの手順と期待値を直す．
そのうえで，要求文の例をテストにする．

## 6-4 性質

在庫についての既存の性質(`invStockNonNegative`，`invStockConsistent`)を，商品ごとの在庫に合わせて書き直す．
次に，引当をしていない注文が商品を引き当てたままになっていないことを，不変条件として書く．
名前は`invReservedOnlyWhileHolding`とする．

## 6-5 検査と反例

`invReservedOnlyWhileHolding`を検査する．

```sh
quint verify shop.qnt --invariants invReservedOnlyWhileHolding --apalache-config=../../../tools/apalache.json
```

反例が出たら，次の問いに答える．

1. 最後の状態で，どの注文が，どの商品を引き当てたままになっているか．
2. その注文は，なぜ断られたか．
3. 要求文は，一部の商品だけ引き当てた注文を断るときの振る舞いについて，何を決めていないか．

## 6-6 決定と反映

6-5で見つけた抜けについて，振る舞いを決める．
決めたら，これまでと同じく決定事項，仕様，テスト，状態遷移図を更新し，`mise run verify`で検査を通す．

## 6-7 振り返り

1. 自分の決定事項を，模範解答と比べる．
2. `shop.qnt`を作業用のディレクトリに写し，定数を変えて，`quint verify --backend=tlc`で不変条件を検査する．
   出力の`distinct states found`の数と，検査の時間を比べる．
   - 再試行の上限`MAX_ATTEMPTS`を3にする．
   - 注文`o3`(りんご1個)を加え，りんごの在庫を2個にする．
3. これまでのIterationの仕様で，何を省いてきたかを挙げる．省いたことで見逃しうる誤りはあるか．
4. 6-5の反例は，注文が何件あれば起きるか．それより大きな定数で検査する意味は何か．

## 6-8 発展課題

在庫の確認と引当を注文単位で1回に行う(すべての商品をまとめて引き当てる)仕様を書き，6-6の仕様と比べる．
状態の数と，実装に必要な仕組みの違いを考える．

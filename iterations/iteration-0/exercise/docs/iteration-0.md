# Iteration 0：注文と在庫の引当

顧客の注文を受け付け，在庫を引き当てる仕様を書く．
要求文の例をテストにし，要求文から性質を読み取って検査する．
テストは通るのに，検査が反例を出すことを確かめ，反例から要求の抜けを見つけて直す．

作業はすべて，このディレクトリ(`iterations/iteration-0/exercise`)で行う．

## 0-1 準備

リポジトリの直下で次を実行し，検査が通ることを確かめる．

```sh
mise run verify iterations/iteration-0/exercise
```

```text
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 2m ago)
Lockfile is up to date, resolution step is skipped
Done in 21ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-0/exercise
ok  Quintの評価器とApalache

iterations/iteration-0/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  状態遷移図
Finished in 1.67s
```

このディレクトリには，次のファイルがある．

| ファイル | 内容 |
| --- | --- |
| `requirements.md` | 要求文．決定事項の節は空である |
| `shop.qnt` | 仕様．モジュールの宣言だけがある |
| `shop_test.qnt` | シナリオのテスト．`shop`を読み込む宣言だけがある |
| `state-diagram.md` | 状態遷移図．仕様から生成する |

## 0-2 基礎知識と構文

次を読む．

- [状態遷移系](../../../../docs/concepts/state-transition-system.md)
- [不変条件](../../../../docs/concepts/invariant.md)
- [テスト・シミュレーション・モデル検査](../../../../docs/concepts/testing-and-model-checking.md)
- [Iteration 0の構文とコマンド](../../../../docs/quint/iteration-0.md)
- [仕様の穴を見つけて直す進め方](../../../../docs/method.md)

読んだら，`quint`でREPLを起動し，次を試す．

1. `Map("apple" -> 1, "banana" -> 2)`の`"banana"`の値を`3`にしたマップを作る．
2. 席の状態を表す型`Seat`(`Free`または`Taken`)を定義する．
   2つの席`"s1"`と`"s2"`がどちらも`Free`のマップから，`"s1"`を`Taken`にしたマップを作り，`"s1"`の値が`Taken`かを確かめる．
3. チケットの残り枚数を表す状態変数`tickets`と，残りが1枚の初期状態を定義する．
   残りがあるときだけ1枚売るアクション`sell`を定義し，`init`のあとに`sell`を2回入力する．
   それぞれで`true`と`false`のどちらが表示されるかを予想してから試す．

## 0-3 シナリオのテスト

`requirements.md`の要求文を読む．

- 顧客は商品を1個注文できる．
- 注文を受け付けると，在庫を1個引き当てる．
- 例：在庫が1個のとき，注文を1件受け付けると在庫は0個になる．

要求文の例を`shop_test.qnt`のテストにし，それが通るように`shop.qnt`を書く．
仕様では，次の名前を使う．

| 名前 | 種類 | 内容 |
| --- | --- | --- |
| `OrderStatus` | 型 | 注文の状態．まだ注文していない状態`NotPlaced`と，在庫を引き当てた状態`Reserved` |
| `INITIAL_STOCK` | 定数 | はじめの在庫数．`1` |
| `stock` | 状態変数 | 在庫数 |
| `orderStatus` | 状態変数 | 注文ごとの状態．注文は`"o1"`と`"o2"`の2件を考える |
| `placeOrder(order: str)` | アクション | 注文を受け付け，在庫を1個引き当てる |
| `placeOneOrderTest` | テスト | 要求文の例 |

次のヒントを参考にする．

- `init`では，2件の注文をどちらも`NotPlaced`にする．
- `step`では，2件の注文のどちらかが注文される遷移を`any`で並べる．
- `quint typecheck shop_test.qnt`で型の誤りを直してから，`quint test shop_test.qnt`を実行する．

## 0-4 性質

要求文には書かれていないが，在庫の数について当然守られるべきことがある．
それを不変条件として`shop.qnt`に書く．名前は`inv`で始める．

## 0-5 検査と反例

書いた不変条件を，ランダムシミュレーションとモデル検査で調べる．

```sh
quint run shop.qnt --invariant=<不変条件の名前> --max-samples=1000 --seed=1
quint verify shop.qnt --invariants <不変条件の名前>
```

反例が出たら，次の問いに答える．

1. 最後の状態で，不変条件のどこが破れているか．
2. どの遷移が，どの順番で起きたか．
3. その順番で遷移が起きることについて，要求文は何を決めていないか．

0-3のテストが通っていたのに反例が出た理由も考える．

## 0-6 決定と反映

0-5で見つけた抜けについて，システムがどう振る舞うべきかを開発者として決める．
決めたら，次を行う．

1. `requirements.md`の決定事項に，決めた振る舞いを書く．
   行末に，それを保証する不変条件の名前を`(性質：名前)`の形で添える．
2. `shop.qnt`を直す．新しい状態やアクションが必要なら加える．
3. 決めた振る舞いを確かめるシナリオのテストを，`shop_test.qnt`に加える．
4. リポジトリの直下で状態遷移図を生成し直し，図を確かめる．

   ```sh
   mise run diagram iterations/iteration-0/exercise
   ```

5. `mise run verify iterations/iteration-0/exercise`で，すべての検査が通ることを確かめる．

## 0-7 振り返り

1. 自分の決定事項と仕様を，`solution/`の模範解答と比べる．違う振る舞いを決めた場合，その理由を説明できるか．
2. 0-3のテストだけでは反例が見つからなかったのはなぜか．
3. 0-4で書いた不変条件は，要求文のどの文から読み取ったか．要求文に書かれていない性質を書く必要があったのはなぜか．
4. 状態遷移図を見て，要求文にない遷移や，要求文にある遷移の抜けがないかを確かめる．

## 0-8 発展課題

次の要求を加え，同じ流れ(シナリオのテスト，性質，検査と反例，決定と反映)で進める．

- 顧客は，1件の注文で商品を1個または2個注文できる．
- 例：在庫が2個のとき，2個の注文を1件受け付けると在庫は0個になる．

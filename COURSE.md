# コース計画

このファイルは，教材を作る人のための計画である．
受講者向けの説明は`README.md`と`docs/ROADMAP.md`にある．
各Iterationで作るものは`docs/ROADMAP.md`，環境や書き方の決まりはこのファイルに従う．

## 受講者と目標

- 受講者は，普段のプログラミングと単体テストはできるが，形式手法は初めての開発者である．
- 受講後に，次のことを業務で行えるようになる．
  - 要求文をQuintの仕様と性質にし，モデル検査で要求の抜けを見つける．
  - 反例の状況でシステムがどう振る舞うべきかを決め，要求文と仕様に反映する．
  - 仕様から出したトレースで，実装が仕様どおりに動くかを確かめる．
- 教材は日本語で書く．識別子とコマンドは英語にする．
- Iteration 0から7までの8回の連続講座とする．

## 題材

ECショップの注文処理(在庫の引当，決済，時間切れ，キャンセル，出荷)を題材にする．
システムの構成はC4モデルの図で`docs/ROADMAP.md`の冒頭に示し，全Iterationで変えない．
Iterationごとに，モデル化する範囲を広げる．

## 各Iterationで受講者が書くもの

- `requirements.md`：与えられた要求と，受講者が決めた振る舞い(決定事項)を書く．
  決定事項には，それを保証する性質名を書く．照合スクリプトで`shop.qnt`と突き合わせる．
- `shop.qnt`：状態，アクション，性質を書く．すべての成果物の正本である．
  `quint typecheck`と`quint verify`で検査する．
- `shop_test.qnt`：要求文の例を，`run`で始まるシナリオのテストにする．
  `quint test`で検査する．
- `state-diagram.md`：手では書かず，トレースから生成する．
  生成し直した結果と一致するかを検査する．

### 性質名の決まり

- 不変条件は`inv`で始める(例：`invNoOversell`)．
- 時相論理の性質は`live`で始める(例：`livePaidOrderSettles`)．
- `requirements.md`の決定事項は，行末に`(性質：invNoOversell)`の形で性質名を書く．
- 照合スクリプトは，次の2つが過不足なく一致することを確かめる．
  - `shop.qnt`で，`inv`または`live`で始まる定義．
  - `requirements.md`が参照する性質名．
- 検査のコマンドは，照合スクリプトが集めた性質名を`quint verify --invariants`と`--temporal`に渡す．

### 状態遷移図の生成

- `quint run --mbt --n-traces=<N> --max-samples=<N> --seed=<固定値> --out-itf='<dir>/{seq}.itf.json'`でトレースを出す．
- 各ステップの`mbt::actionTaken`と，注文の状態の変化から，遷移(状態→状態，ラベルはアクション名)を集める．
- 集めた遷移をMermaidの`stateDiagram-v2`として`state-diagram.md`に書く．
- 遷移の取りこぼしがないよう，トレース数とステップ数は各Iterationの仕様に合わせて十分に取る．
  Iterationを作るときに，`quint verify`で到達できる状態と図の状態が一致するかを確かめる．

## 基礎知識のリファレンス

受講者は，形式体系(状態遷移系，時相論理など)にも明るくないものとする．
各Iterationで必要になる形式手法の基礎知識を，`docs/concepts/`にリファレンスとして置く．

- 1ファイルに1つの概念を書く．Quintの構文には依存させず，題材とも別の小さな例で説明する．
- 各ファイルは「一言でいうと」で始め，「なぜ必要か」「テストとの違い」「よくある誤解」を含め，「Quintでの書き方」(構文の解説への参照)で終える．間には，概念に合わせて例や構成要素の節を置く．
- `docs/concepts/README.md`に，Iterationごとに読む概念の一覧を置く．
- 概念のファイルは，それを初めて使うIterationを作るときに書く．
- Quintの構文とコマンドは，`docs/quint/iteration-N.md`に分けて書く．概念の説明と構文の説明を混ぜない．

| # | 読む概念(`docs/concepts/`) |
| --- | --- |
| 0 | 状態遷移系，不変条件，テスト・シミュレーション・モデル検査 |
| 1 | 非決定性，インターリーブと原子性，デッドロック |
| 2 | 環境のモデル化，非同期メッセージ，時間の抽象化 |
| 3 | メッセージの配送保証，冪等性 |
| 4 | 安全性と活性，時相論理，公平性，有界モデル検査と全状態探索 |
| 5 | 結果整合性，補償処理 |
| 6 | 抽象化，状態爆発と小スコープ仮説 |
| 7 | モデルベーステスト，仕様と実装の対応(詳細化) |

## Iterationの教材の構成

`exercise/docs/iteration-N.md`は，次の順に進める．`solution/docs/iteration-N.md`は，同じ見出しで解説を書く．

1. 準備(N-1)：`mise run verify`で`exercise/`を検査し，前のIterationの仕様が検査を通ることを確かめる．
2. 基礎知識と構文(N-2)：`docs/concepts/`の該当する概念と，`docs/quint/iteration-N.md`を読み，REPLで小さな課題を解く．
3. シナリオのテスト(N-3)：要求文の例を`shop_test.qnt`のテストにし，通るまで仕様を書く．
4. 性質(N-4)：要求文から性質を読み取り，`shop.qnt`に書く．
5. 検査と反例(N-5)：`quint run`と`quint verify`で検査し，反例の手順を読み取る．
6. 決定と反映(N-6)：反例の状況での振る舞いを決め，`requirements.md`と`shop.qnt`に反映し，検査を通す．
7. 振り返り(N-7)：模範解答の決定事項と比べ，テストだけでは反例が見つからなかった理由を考える．
8. 発展課題(N-8)：同じ流れで，受講者が1人で進める小さな追加の要求．

課題の手順には，要求文と進め方のヒントだけを書き，反例や決定事項は書かない．

## 開発環境

| 項目 | 内容 |
| --- | --- |
| Node，pnpm，Java | `mise.toml`で固定する．JavaはApalacheとTLCが使う |
| 検査のスクリプト | `tools/`にTypeScriptで書き，Nodeで直接実行する |
| Quint | `package.json`で`@informalsystems/quint`を0.32.0に固定する |
| Quintの評価器 | `Dockerfile`で`v0.6.0`を取得し，`/opt/quint`に置く |
| Apalache | `Dockerfile`で`0.56.1`を取得し，`/opt/quint`に置く |
| 実装とテスト | TypeScript，Vitest(Iteration 7) |
| 文書の検査 | textlintとmarkdownlint(既存の設定) |
| 図の検査 | Mermaidの構文をmermaid-cliで検査する |

### リポジトリの構成

```text
COURSE.md                      コース計画(このファイル)
README.md                      受講者向けの概要と環境の準備
docs/ROADMAP.md                題材，C4図，各Iterationの要求と学ぶこと
docs/method.md                 要求→テスト→性質→反例→決定→反映の進め方
docs/concepts/README.md        基礎知識の目次(Iterationごとに読むもの)
docs/concepts/<topic>.md       形式手法の基礎知識(1ファイル1概念)
docs/quint/README.md           Quintの構文とコマンドの目次
docs/quint/iteration-N.md      Iteration Nで初めて使う構文とコマンドの解説
tools/                         状態遷移図の生成，性質名の照合(TypeScript)
iterations/iteration-N/
  exercise/                    受講者が作業する場所
    README.md                  このIterationで作るもの，進め方
    docs/iteration-N.md        課題の手順
    requirements.md
    shop.qnt
    shop_test.qnt
    state-diagram.md
  solution/                    同じ構成の模範解答(docs/iteration-N.md は解説)
    (Iteration 7のみ) impl/    TypeScriptの実装とトレースのテスト
```

### コマンド

| コマンド | 内容 |
| --- | --- |
| `mise run check` | リントとすべての仕様の検査をまとめて実行する．CIでも同じものを実行する |
| `mise run verify <dir>` | 指定したディレクトリの仕様だけを検査する．受講者は`exercise/`に対して使う |
| `mise run diagram <dir>` | 指定したディレクトリの状態遷移図を生成し直す |

仕様の検査(`tools/check.ts`)は，はじめに`QUINT_HOME`の評価器とApalacheを確かめ，続けて各ディレクトリで次を実行する．

1. `quint typecheck`，`quint test`．
2. 性質名の照合．
3. `quint verify`．不変条件と時相論理の性質を，TLC(`--backend=tlc`)で検査する．時相論理の性質がないときは，その検査を表示しない．
4. 状態遷移図を生成し直し，コミット済みの図との差分がないかを確かめる．

リント(`pnpm lint`)は，textlint，markdownlint，Mermaidの構文の検査，`tsc --noEmit`を実行する．
Iteration 7では，実装のテスト(`pnpm vitest`)を検査に加える．

`exercise/`は，前のIterationの`solution/`と同じ仕様に，新しい要求を加えたものである．
新しい要求は性質名を参照しないので，`exercise/`も初めから検査を通る．

### 受講者のツール操作

| Iteration | 初めて行う操作 |
| --- | --- |
| 0 | `mise run verify`，`mise run diagram`，`quint typecheck`，`quint run`，`quint test`，`quint verify`，REPL |
| 1 | `quint run`の`--max-samples` |
| 2 | `--invariants`で複数の不変条件をまとめて検査する |
| 4 | `quint verify --backend=tlc`，`--temporal` |
| 6 | 定数を変えたモジュールを用意し，`quint verify`の時間を比べる |
| 7 | `quint run --mbt --out-itf`，`pnpm add -D vitest`，`pnpm vitest` |

## Iteration 0の課題の形

- `requirements.md`：与える要求だけを書く．決定事項の節は見出しだけ置く．
- `shop.qnt`：モジュールの宣言だけを置く．
- `shop_test.qnt`：`shop`を読み込む宣言だけを置く．
- `state-diagram.md`：生成した図を置く場所の説明だけを置く．

## 模範解答の方針

各Iterationで，要求文のままだと出る反例と，`solution/`の決定事項は次のとおりとする．
受講者が別の振る舞いを決めても，性質と仕様が一致していれば正解である．

| # | 要求文のままだと出る反例 | 決定事項 |
| --- | --- | --- |
| 0 | 同じ顧客が続けて注文すると，在庫が負になる | 在庫が0なら注文を断る |
| 1 | 2人がそれぞれ在庫を確かめてから引き当てると，売り越す | 在庫の確認と引当を1つの操作にする |
| 2 | 時間切れで引当を解除したあとに，決済成功の通知が届く | 自動で返金し，注文は時間切れのままにする |
| 3 | 再試行した依頼が2つとも処理され，二重に課金される．重複した通知で二重に返金する | 決済代行サービスの冪等キーを使う．返金は課金の回数までにする |
| 4 | 何も起きずに，注文が決済待ちのまま，または時間切れで課金されたまま止まり続ける | 時間切れ監視ジョブが必ず動くことと，通知が必ず受け取られることを公平性として仮定し，要求文に書く |
| 5 | 返金と発送が両方起きる．取消依頼中のまま残る | 出荷指示の後は取消依頼にし，いずれ決着させる |
| 6 | 一部の商品だけ在庫切れのとき，引き当てた商品が戻らない | 注文単位で，すべて引き当てるか，すべて断る |

Iteration 5では，2段階で反例が出る．

1. キャンセルと出荷指示が行き違い，返金と発送が両方起きる．
   出荷指示の前はその場でキャンセルし，後は配送システムへの取消依頼にすると決める．
2. 取消依頼の結果が届かず，注文が取消依頼中のまま残る．
   取消依頼中の注文は，いずれ「取消成功→返金」か「発送済み→返金しない」に決着すると決める．

## 落とし穴

- Quintは，評価器をGitHub APIのリリース一覧から探してダウンロードする．APIが使えない環境では失敗するので，`Dockerfile`で`QUINT_HOME`(`/opt/quint`)に置いておく．
  評価器とApalacheの版は，Quint本体に埋め込まれた版(`QUINT_EVALUATOR_VERSION`，`DEFAULT_APALACHE_VERSION_TAG`)と一致させる．Quintの版を上げるときは，`Dockerfile`の版も上げる．
- 動けるアクションがなくなると，`quint run`のトレースはそこで終わる．
  `quint verify`(Apalache)は，この状態をデッドロックとして違反にする．
  受講者がApalacheを直接使うときは，`tools/apalache.json`でデッドロックの検査を切る．
  検査のスクリプトはTLCを使う．QuintはTLCを`-deadlock`付きで呼ぶので，デッドロックは違反にならない．
- `quint verify --backend=tlc`は速いが，反例をTLA+の記法で表示する．教材で受講者に不変条件の反例を読ませるときは，Apalacheで出す．
- Apalacheの不変条件の検査は，Iteration 5の仕様で約5分かかった．検査のスクリプトは，不変条件もTLCで検査する．
- Apalacheで時相論理の性質を検査すると，Iteration 4の仕様でも10分以上かかった．時相論理の性質はTLCで検査する．TLCは状態の数が有限でなければ終わらないので，再試行などの回数には上限を設ける．
- `weakFair(step, vars)`のように`step`全体に公平性を仮定すると，特定のアクションが起きることは保証されない．公平性は，起きてほしいアクションごとに仮定する．
- `quint run --out-itf`の出力先のディレクトリは，先に作っておく．
- pnpm 12は，公開から間もない版をロックファイルに入れることを拒む(`minimumReleaseAge`)．依存パッケージの追加には，`mise.toml`で固定したpnpmを使う．
- pnpm 12は，インストール時スクリプトの可否が決まっていない依存パッケージがあると，インストールを失敗にする．可否は`pnpm-workspace.yaml`の`allowBuilds`に書く．
- `quint run`は，`--seed`を指定すると`--max-samples`の既定値が1になる．教材に載せる出力は，`--seed`と`--max-samples`を両方指定して取る．
- REPLに標準入力から式を流すときは，入力の後に数秒待ってから`.exit`を送る．すぐに入力が閉じると，評価器が`readline was closed`で止まる．
- MermaidのC4図は，矢印の配置を細かく指定できない．矢印が重なって読みにくいときは，要素の宣言の順番を入れ替える．

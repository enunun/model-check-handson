# Iteration 0の構文とコマンド

Iteration 0で初めて使う，Quintの構文とコマンドを説明する．
概念の説明は，[状態遷移系](../concepts/state-transition-system.md)，[不変条件](../concepts/invariant.md)，[テスト・シミュレーション・モデル検査](../concepts/testing-and-model-checking.md)にある．

## モジュールとコメント

仕様は`module`の中に書く．
`//`から行末まではコメントである．

```quint
// 信号機の仕様．
module trafficLight {
  // ここに型，定数，状態変数，アクション，性質を書く．
}
```

別のファイルのモジュールは，`import`で読み込む．
`import trafficLight.* from "./trafficLight"`は，`trafficLight.qnt`のモジュールの定義をすべて読み込む．

## 値と式

| 書き方 | 意味 | 例 |
| --- | --- | --- |
| 整数 | `int`型の値 | `0`，`-1`，`1 + 2 * 3` |
| 文字列 | `str`型の値 | `"o1"` |
| 比較 | 等しい，等しくない，大小 | `x == 0`，`x != 0`，`x > 0` |
| 論理 | かつ，または，ならば，でない | `a and b`，`a or b`，`a implies b`，`not(a)` |

## 定数と型

`pure val`は，状態によらない定数を定義する．

```quint
pure val MAX_WAIT = 3
```

`type`で，とりうる値を列挙した型(バリアント型)を定義する．

```quint
type Light = Red | Yellow | Green
```

## マップ

`Map(キー -> 値, ...)`は，キーから値への対応である．
`get`で値を取り出し，`set`で1つのキーの値を変えた新しいマップを作る．
型は`キーの型 -> 値の型`と書く(例：`str -> int`)．

## 状態変数とアクション

`var`で状態変数を宣言する．

```quint
var light: Light
```

`action`は遷移を定義する．
`all { ... }`の中に，条件と変化を並べる．
`x' = 式`は「遷移のあとで`x`を式の値にする」という意味である．
条件がすべて成り立つときだけ，遷移が起きる．

```quint
action toYellow = all {
  light == Green,
  light' = Yellow,
}
```

アクションでは，すべての状態変数の次の値を決める．
値を変えない状態変数にも，`x' = x`と書く．

アクションは引数を取れる．

```quint
action press(button: str): bool = all {
  button == "walk",
  light' = Red,
}
```

`any { a, b, ... }`は，並べたアクションのうち，条件を満たすどれか1つが起きることを表す．

## 初期状態と遷移

Quintのコマンドは，次の2つのアクションを使う．

- `init`：初期状態を決める．
- `step`：各ステップで起きうる遷移をまとめる．

```quint
action init = all {
  light' = Red,
}

action step = any {
  toGreen,
  toYellow,
  toRed,
}
```

## 性質

状態変数についての真偽値の式を`val`で定義すると，不変条件として検査できる．
このハンズオンでは，不変条件の名前を`inv`で始める．

```quint
val invNeverDark = light == Red or light == Yellow or light == Green
```

## シナリオのテスト

`run`で，手順と期待する状態を書く．
`init`から始め，`.then(アクション)`で遷移を1つ進め，`.expect(条件)`で状態を確かめる．
このハンズオンでは，テストの名前を`Test`で終える．

```quint
run greenAfterRedTest =
  init
    .then(toGreen)
    .expect(light == Green)
```

## REPL

`quint`を引数なしで実行すると，REPLが起動する．
式を入力すると，その値が表示される．`.exit`で終わる．

```text
>>> 1 + 2 * 3
7
>>> Map("o1" -> 10, "o2" -> 20).get("o1")
10
>>> Map("o1" -> 10, "o2" -> 20).set("o2", 25)
Map("o1" -> 10, "o2" -> 25)
>>> type Light = Red | Green
>>> Red == Green
false
```

REPLでは，状態変数とアクションも試せる．
アクションを入力すると，遷移が起きたときは`true`，条件を満たさず起きなかったときは`false`が表示される．

```text
>>> var count: int
>>> action init = count' = 0
>>> action increment = all { count < 2, count' = count + 1 }
>>> init
true
>>> count
0
>>> increment
true
>>> count
1
>>> increment
true
>>> increment
false
>>> count
2
```

## コマンド

仕様のファイルがあるディレクトリで実行する．

| コマンド | 内容 |
| --- | --- |
| `quint typecheck <ファイル>` | 型の誤りがないかを確かめる |
| `quint test <テストのファイル>` | `run`で書いたテストを実行する |
| `quint run <仕様のファイル> --invariant=<性質名>` | ランダムシミュレーションで，性質が破れる実行を探す |
| `quint verify <仕様のファイル> --invariants <性質名>` | モデル検査で，すべての実行について性質を調べる |

`quint run`のおもなオプションは次のとおりである．

| オプション | 内容 |
| --- | --- |
| `--max-samples=<N>` | 作る実行の数(既定は10000．`--seed`を指定したときは1) |
| `--max-steps=<N>` | 1つの実行のステップ数の上限(既定は20) |
| `--seed=<N>` | 乱数の種．同じ値を指定すると，同じ結果が再現する．`--max-samples`と一緒に指定する |

`quint run`と`quint verify`の出力と，反例の読み方は[進め方](../method.md#検査)にある．

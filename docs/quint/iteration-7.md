# Iteration 7の構文とコマンド

Iteration 7で初めて使う，Quintのコマンドとトレースの形式，Vitestを説明する．
概念の説明は，[モデルベーステスト](../concepts/model-based-testing.md)，[仕様と実装の対応(詳細化)](../concepts/refinement.md)にある．

## トレースを出力する

`quint run`に次のオプションを付けると，トレースをファイルに出力する．

| オプション | 内容 |
| --- | --- |
| `--mbt` | 各状態に，直前に起きたアクション(`mbt::actionTaken`)と選ばれた値(`mbt::nondetPicks`)を加える |
| `--out-itf=<ファイル>` | トレースをITF形式で出力する．`{seq}`はトレースの番号に置き換わる |
| `--n-traces=<N>` | 出力するトレースの本数 |

```sh
quint run shop.qnt --mbt --max-samples=1 --n-traces=1 --max-steps=2 --seed=1 --out-itf=trace.itf.json
```

出力先のディレクトリは，先に作っておく．

## ITF形式

ITF(Informal Trace Format)は，トレースを表すJSONである．
`states`に状態の列が入り，各状態は状態変数の名前と値の組である．
値は，次の形で表される．

| Quintの値 | ITFの形 |
| --- | --- |
| 整数 | `{ "#bigint": "1" }` |
| マップ | `{ "#map": [[キー, 値], ...] }` |
| 集合 | `{ "#set": [要素, ...] }` |
| タプル | `{ "#tup": [要素, ...] }` |
| バリアント | `{ "tag": "Checked", "value": { "#tup": [] } }` |
| 文字列，真偽値 | そのまま |

上のコマンドで出力したトレースの，2つ目の状態の一部を示す．

```json
{
  "#meta": {
    "index": 1
  },
  "mbt::actionTaken": "checkStock",
  "mbt::nondetPicks": {
    "order": {
      "tag": "Some",
      "value": "o1"
    },
    "product": {
      "tag": "Some",
      "value": "apple"
    }
  },
  "orderStatus": {
    "#map": [
      [
        "o1",
        {
          "tag": "Checked",
          "value": {
            "#tup": []
          }
        }
      ],
      [
        "o2",
        {
          "tag": "NotPlaced",
          "value": {
            "#tup": []
          }
        }
      ]
    ]
  }
}
```

`mbt::nondetPicks`には，そのステップで`nondet`の選んだ値が`Some`で入る．選ばなかった名前は`None`になる．

## トレースを読み込む

リポジトリの`tools/lib/itf.ts`に，トレースを生成してTypeScriptの値に変換する関数がある．

| 関数 | 内容 |
| --- | --- |
| `generateTraces(仕様のファイル, { traces, maxSteps, seed })` | `quint run --mbt`でトレースを生成し，読み込む |
| `decode(値)` | ITFの値を変換する．整数は`number`，マップは`Map`，集合は`Set`，タプルは配列，バリアントは`{ tag, value }`になる |

各ステップは`{ action, picks, vars }`になる．`picks`には，選ばれた値だけが入る．

## Vitest

Vitestは，TypeScriptのテストの道具である．
`*.test.ts`のファイルに，`test`でテストを書き，`expect`で値を比べる．
`test.each`は，配列の要素ごとにテストを作る．

```ts
import { expect, test } from "vitest";

test.each([[1, 2], [2, 4]])("%iを2倍すると%i", (x, doubled) => {
  expect(x * 2).toEqual(doubled);
});
```

リポジトリの直下で，ディレクトリを指定して実行する．

```sh
pnpm exec vitest run iterations/iteration-7/exercise/impl
```

`mise run verify`は，ディレクトリに`impl/`があれば，このテストも実行する．

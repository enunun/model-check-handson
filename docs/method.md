# 仕様の穴を見つけて直す進め方

このハンズオンでは，どのIterationも同じ流れで進める．
要求文を仕様にし，検査で反例を見つけ，反例から要求の抜けを読み取って直す．
この文書では，その流れと，各ファイルの書き方を説明する．

例には，ECショップとは別の小さな仕様(エレベーターの扉と移動)を使う．
仕様は`docs/examples/elevator.qnt`，シナリオのテストは`docs/examples/elevator_test.qnt`にある．

## 1回の流れ

1. 要求文を読む．
2. 要求文の例を，シナリオのテストにする．
3. 状態とアクションを仕様に書き，テストを通す．
4. 要求文から性質を読み取り，仕様に書く．
5. 検査して，反例を読む．
6. 反例の状況でどう振る舞うべきかを決め，要求文と仕様に反映する．
7. 検査がすべて通るまで，4から6を繰り返す．

## 要求文(`requirements.md`)

`requirements.md`は，2つの節からなる．

- 要求：Iterationの初めに与えられる要求．受講者は書き換えない．
- 決定事項：検査で見つけた抜けについて，受講者が決めた振る舞い．

決定事項には，それを保証する性質の名前を行末に書く．
性質名は，`(性質：名前)`の形で書く．複数あるときは，全角の読点で区切る．

```markdown
## 要求

- 移動を始めるときは，扉が閉まっている．
- 移動中は扉が開かない．

## 決定事項

- 扉を開けるのは，止まっているときだけにする．(性質：invDoorClosedWhileMoving)
```

仕様の性質と，決定事項が参照する性質名は，過不足なく一致させる．
一致しないと，`mise run verify`が失敗する．

## シナリオのテスト(`shop_test.qnt`)

シナリオのテストは，要求文に書かれた具体的な手順を，その順に実行して確かめる．
テストの名前は`Test`で終える．

```quint
module elevator_test {
  import elevator.* from "./elevator"

  // 扉を閉めてから移動を始め，止まってから扉を開ける．
  run normalRideTest =
    init
      .then(startMoving)
      .expect(motion == Moving and door == Closed)
      .then(stop)
      .then(openDoor)
      .expect(motion == Stopped and door == Open)
}
```

```text
$ quint test elevator_test.qnt

  elevator_test
    ok normalRideTest passed 1 test(s)

  1 passing (25ms)
```

このテストは通る．
しかし，テストが確かめるのは，書いた手順だけである．

## 性質(`shop.qnt`)

性質は，どんな手順で動いても成り立つべきことである．
性質の名前は，種類によって次のように始める．

| 種類 | 名前の始め | 例 |
| --- | --- | --- |
| 不変条件(どの状態でも成り立つ) | `inv` | `invDoorClosedWhileMoving` |
| 時相論理の性質(実行の全体について成り立つ) | `live` | Iteration 4で扱う |

```quint
// 要求: 移動中は扉が開かない．
val invDoorClosedWhileMoving = motion == Moving implies door == Closed
```

## 検査

性質は，2つの方法で検査する．

- `quint run`：ランダムに選んだ手順で何度も実行し，性質が破れる実行を探す．
- `quint verify`：決めた長さまでの，すべての手順を調べる．

```text
$ quint run elevator.qnt --invariant=invDoorClosedWhileMoving \
    --max-samples=1000 --seed=1
An example execution:

[State 0] { door: Closed, motion: Stopped }

[State 1] { door: Closed, motion: Moving }

[State 2] { door: Closed, motion: Moving }

[State 3] { door: Closed, motion: Stopped }

[State 4] { door: Open, motion: Stopped }

[State 5] { door: Open, motion: Stopped }

[State 6] { door: Closed, motion: Stopped }

[State 7] { door: Closed, motion: Moving }

[State 8] { door: Open, motion: Moving }

[violation] Found an issue (22ms at 45 traces/second).
Use --verbosity=3 to show executions.
Use --seed=0x1 --backend=rust to reproduce.
error: Invariant violated
```

`quint verify`は，最も短い反例を示す．

```text
$ quint verify elevator.qnt --invariants invDoorClosedWhileMoving
An example execution:

[State 0] { door: Closed, motion: Stopped }

[State 1] { door: Closed, motion: Moving }

[State 2] { door: Open, motion: Moving }

[violation] Found an issue (4724ms).
error: found a counterexample
```

## 反例の読み方

反例は，初期状態から性質が破れる状態までの，状態の列である．
次の順に読む．

1. 最後の状態で，性質のどこが破れているかを確かめる．
   上の例では，`motion`が`Moving`なのに`door`が`Open`である．
2. 1つ前の状態から最後の状態へ，何が変わったかを見る．
   `door`だけが`Closed`から`Open`に変わったので，扉を開けるアクションが起きたと分かる．
3. そのアクションが，その状態で起きてよいのかを要求文で確かめる．
   要求文は「移動を始めるとき」の扉の状態を決めているが，「扉を開けるとき」の条件を決めていない．
   これが要求の抜けである．
4. 抜けについて，システムがどう振る舞うべきかを決める．
   ここでは「扉を開けるのは，止まっているときだけにする」と決める．
5. 決めた振る舞いを，要求文の決定事項と仕様のアクションに反映する．
   `openDoor`に`motion == Stopped`という条件を加えると，検査が通る．

各状態がどのアクションで作られたかを直接見たいときは，`quint run`に`--mbt`を付ける．
状態ごとに，直前に起きたアクション(`mbt::actionTaken`)と，そのとき選ばれた値(`mbt::nondetPicks`)が表示される．
次の出力は，先頭の2つの状態だけを示す．

```text
$ quint run elevator.qnt --invariant=invDoorClosedWhileMoving \
    --max-samples=1000 --seed=1 --mbt
An example execution:

[State 0]
{
  door: Closed,
  mbt::actionTaken: "init",
  mbt::nondetPicks: {  },
  motion: Stopped
}

[State 1]
{
  door: Closed,
  mbt::actionTaken: "startMoving",
  mbt::nondetPicks: {  },
  motion: Moving
}
```

## コマンド

| コマンド | 内容 |
| --- | --- |
| `mise run verify <dir>` | 指定したディレクトリの仕様を検査する |
| `mise run diagram <dir>` | 仕様のトレースから，状態遷移図(`state-diagram.md`)を生成し直す |
| `mise run check` | リントと，すべてのIterationの仕様の検査をまとめて実行する |

`mise run verify`は，次の順に検査する．

1. `quint typecheck`：仕様とテストに，型の誤りがないか．
2. `quint test`：シナリオのテストが通るか．
3. 性質名の照合：要求文の決定事項と，仕様の性質が一致しているか．
4. `quint verify`：すべての不変条件が成り立つか．
   時相論理の性質(Iteration 4から)があれば，`quint verify(時相論理の性質)`として別に検査する．
5. 状態遷移図：`state-diagram.md`が，仕様から生成した図と一致しているか．

状態遷移図は手で書かない．
仕様を変えたら`mise run diagram`で生成し直し，図の変化を確かめる．

# Iteration 5の構文とコマンド

Iteration 5で初めて使う，Quintの書き方を説明する．
概念の説明は，[結果整合性](../concepts/eventual-consistency.md)，[補償処理](../concepts/compensation.md)にある．

Iteration 5では，新しい構文は加わらない．
これまでの構文を組み合わせて，大きくなった仕様を扱う書き方を説明する．

## 状態変数を加えるときの手順

状態変数を加えると，すべてのアクションに，その変数の次の値を書く必要がある．
次の順に進めると，書き忘れを`quint typecheck`で見つけられる．

1. `var`で状態変数を宣言し，`init`で初期値を決める．
2. 既存のすべてのアクションに，`x' = x`を加える．
3. `quint typecheck`で，書き忘れがないことを確かめる．
4. 新しいアクションを加え，`step`に並べる．
5. 公平性で使う状態変数の組`vars`に，新しい変数を加える．

`vars`に加え忘れると，公平性の意味が変わる．
`weakFair(A, vars)`は「`vars`のどれかが変わるような`A`」についての仮定なので，変わる変数が`vars`になければ，その変化は数えられない．

## 値の中の条件式

条件式は，値を書くところならどこでも使える．
メッセージの内容を条件で変えるときに使う．

```quint
withdrawNotices' = withdrawNotices.union(Set((order, if (shipment.get(order) == Dispatched) WithdrawRefused else WithdrawDone))),
```

## 公平性の組み合わせ

複数の公平性は`and`でつなぐ．
性質ごとに，必要な公平性だけを前提にする．

```quint
temporal livePaidOrderSettles =
  (expireIsFair and notificationIsFair and logisticsIsFair) implies
    ORDERS.forall(o => always(unsettled(o) implies eventually(not(unsettled(o)))))
```

## 既存の性質を見直す

注文の状態を加えると，状態の集合を使っている既存の性質が，意図と合わなくなることがある．
状態を加えたら，次を確かめる．

- 不変条件や`def`の中の`Set(...)`に，新しい状態を加える必要はないか．
- `!=`や`==`で1つの状態と比べている条件は，新しい状態でも正しいか．

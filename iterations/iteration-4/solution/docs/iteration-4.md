# Iteration 4：注文が必ず決着する(解説)

課題の各段階について，模範解答とその考え方を示す．

## 4-1 準備

課題のディレクトリの仕様は，Iteration 3の模範解答と同じなので，検査を通る．
仕様にはまだ時相論理の性質がないので，`quint verify(時相論理の性質)`は表示されない．

## 4-2 基礎知識と構文

1. `liveGreenAfterRed`は，赤のまま何も起きない実行(`State 2: Stuttering`)を反例として示す．`liveGreenAfterRedFair`は検査を通る．
   仕様は信号が切り替わることを許すだけで，切り替わることを求めていない．公平性の仮定が，それを求める．
2. `toYellow`の条件を`light == Red`に変えると，赤から黄にも変われるようになる．
   公平性を仮定していても，`liveGreenAfterRedFair`は破れ，反例は`Back to state 2`で終わる．

   ```text
   $ quint verify --backend=tlc trafficLight.qnt --temporal=liveGreenAfterRedFair
   ...
   Error: The following behavior constitutes a counter-example:

   State 1: <Initial predicate>
   light = [Red |-> [tag |-> "UNIT"]]

   State 2: <toYellow line 39, col 13 to line 39, col 45 of module trafficLight>
   light = [Yellow |-> [tag |-> "UNIT"]]

   State 3: <toRed line 44, col 10 to line 44, col 42 of module trafficLight>
   light = [Red |-> [tag |-> "UNIT"]]

   Back to state 2: <toYellow line 39, col 13 to line 39, col 45 of module trafficLight>

   Finished checking temporal properties in 00s at 2026-09-27 05:34:14
   4 states generated, 3 distinct states found, 0 states left on queue.
   Finished in 00s at (2026-09-27 05:34:14)

   [violation] Found an issue (860ms).
   error: found a counterexample
   ```

   赤，黄，赤，黄と切り替わり続け，青にならない．
   `switchIsFair`は`step`全体の公平性なので，何かが切り替わり続ければ満たされる．青に変わる`toGreen`が選ばれることまでは求めていない．
   公平性をどのアクションに仮定するかで，検査の結果が変わる．

## 4-3 シナリオのテスト

要求文はテストにできない．
テストは有限の手順を実行し，その時点の状態を確かめる．
「いずれ確定するか返金される」は，どれだけ手順を進めても，まだ起きていないだけでその先で起きる可能性が残るので，有限の手順では確かめられない．
テストで書けるのは，「この手順のあとでは返金されている」という個別の場合だけであり，それはIteration 2と3のテストですでに確かめている．
そのため，Iteration 4ではテストを加えない．

## 4-4 性質

```quint
  // 支払いを済ませ，まだ確定も返金もされていない注文．
  def unsettled(o: str): bool = charges.get(o) > refunds.get(o) and orderStatus.get(o) != Confirmed

  // 注文は，いつまでも決済待ちのままにはならない．
  temporal liveNoEndlessAwaiting =
    ORDERS.forall(o => always(orderStatus.get(o) == AwaitingPayment implies eventually(orderStatus.get(o) != AwaitingPayment)))

  // 支払いを済ませた注文は，いずれ確定するか返金される．
  temporal livePaidOrderSettles =
    ORDERS.forall(o => always(unsettled(o) implies eventually(not(unsettled(o)))))
```

`unsettled`は，課金の回数が返金の回数より多く，注文が確定していない状態である．
確定した注文は，課金されていても決着している．

## 4-5 検査と反例

`liveNoEndlessAwaiting`の反例は長いので，最後の2つの状態だけを示す．

```text
$ quint verify --backend=tlc shop.qnt --temporal=liveNoEndlessAwaiting
...
State 7: <processPayment line 240, col 3 to line 273, col 81 of module shop>
/\ charges = [o1 |-> 0, o2 |-> 1]
/\ stock = 0
/\ attempts = [o1 |-> 0, o2 |-> 2]
/\ notifications = {<<"o2", [Success |-> [tag |-> "UNIT"]]>>}
/\ requests = [o1 |-> 0, o2 |-> 0]
/\ refunds = [o1 |-> 0, o2 |-> 0]
/\ paymentRecord = [ o1 |-> [NotProcessed |-> [tag |-> "UNIT"]],
  o2 |-> [Processed |-> [Success |-> [tag |-> "UNIT"]]] ]
/\ orderStatus = [ o1 |-> [Rejected |-> [tag |-> "UNIT"]],
  o2 |-> [AwaitingPayment |-> [tag |-> "UNIT"]] ]

State 8: Stuttering
Finished checking temporal properties in 00s at 2026-09-27 05:24:48
2955 states generated, 658 distinct states found, 0 states left on queue.
Finished in 00s at (2026-09-27 05:24:48)

[violation] Found an issue (1102ms).
error: found a counterexample
```

`livePaidOrderSettles`の反例も，最後の2つの状態だけを示す．

```text
$ quint verify --backend=tlc shop.qnt --temporal=livePaidOrderSettles
...
State 13: <processPayment line 240, col 3 to line 273, col 81 of module shop>
/\ charges = [o1 |-> 1, o2 |-> 0]
/\ stock = 1
/\ attempts = [o1 |-> 2, o2 |-> 2]
/\ notifications = { <<"o1", [Success |-> [tag |-> "UNIT"]]>>,
  <<"o2", [Failure |-> [tag |-> "UNIT"]]>> }
/\ requests = [o1 |-> 0, o2 |-> 0]
/\ refunds = [o1 |-> 0, o2 |-> 0]
/\ paymentRecord = [ o1 |-> [Processed |-> [Success |-> [tag |-> "UNIT"]]],
  o2 |-> [Processed |-> [Failure |-> [tag |-> "UNIT"]]] ]
/\ orderStatus = [ o1 |-> [Expired |-> [tag |-> "UNIT"]],
  o2 |-> [PaymentFailed |-> [tag |-> "UNIT"]] ]

State 14: Stuttering
Finished checking temporal properties in 00s at 2026-09-27 05:24:54
2955 states generated, 658 distinct states found, 0 states left on queue.
Finished in 00s at (2026-09-27 05:24:54)

[violation] Found an issue (1037ms).
error: found a counterexample
```

問いへの答えは次のとおりである．

1. `liveNoEndlessAwaiting`では，注文`o2`が`AwaitingPayment`のままである．`livePaidOrderSettles`では，注文`o1`が`Expired`で，課金が1回，返金が0回である．
2. どちらも`Stuttering`で終わる．その状態から先，何も起きずに止まり続ける実行である．
3. `liveNoEndlessAwaiting`では，通知の受け取り(`receiveNotification`)か時間切れ(`expire`)が起きれば，決済待ちでなくなる．どちらも起きることができた．
   `livePaidOrderSettles`では，成功の通知の受け取りが起きれば返金される．通知は集合にあるので，受け取ることができた．
4. 要求文は，時間切れ監視ジョブが動くことや，通知が受け取られることを決めていない．仕様は，それらが「起きてもよい」と書くだけである．

## 4-6 決定と反映

時間切れ監視ジョブが必ず動くことを，公平性として仮定する．
`liveNoEndlessAwaiting`の前提にすると，検査を通る．
同じ仮定だけを`livePaidOrderSettles`の前提にしても，まだ反例が残る．

```text
$ quint verify --backend=tlc shop.qnt --temporal=livePaidOrderSettles
...
State 8: <expire line 296, col 3 to line 304, col 38 of module shop>
/\ charges = [o1 |-> 0, o2 |-> 1]
/\ stock = 1
/\ attempts = [o1 |-> 0, o2 |-> 2]
/\ notifications = {<<"o2", [Success |-> [tag |-> "UNIT"]]>>}
/\ requests = [o1 |-> 0, o2 |-> 0]
/\ refunds = [o1 |-> 0, o2 |-> 0]
/\ paymentRecord = [ o1 |-> [NotProcessed |-> [tag |-> "UNIT"]],
  o2 |-> [Processed |-> [Success |-> [tag |-> "UNIT"]]] ]
/\ orderStatus = [o1 |-> [Rejected |-> [tag |-> "UNIT"]], o2 |-> [Expired |-> [tag |-> "UNIT"]]]

State 9: Stuttering
Finished checking temporal properties in 00s at 2026-09-27 05:25:09
2955 states generated, 658 distinct states found, 0 states left on queue.
Finished in 00s at (2026-09-27 05:25:09)

[violation] Found an issue (1075ms).
error: found a counterexample
```

時間切れで`Expired`になった注文の成功の通知が，受け取られないまま止まっている．
時間切れ監視ジョブが動いても，返金は通知の受け取りで起きるので，通知が受け取られなければ返金されない．
そこで，通知がいずれ必ず受け取られることも仮定する．
これは，決済代行サービスが受け取りの確認まで通知を送り直すこと(最低1回の配送)と，ECショップの受信処理が止まらないことを前提にする．

```markdown
### Iteration 4

- 時間切れ監視ジョブは，決済待ちの注文があれば，いずれ必ず動く．ジョブが止まったら，監視の仕組みで検知して再起動する．(性質：liveNoEndlessAwaiting)
- 決済代行サービスの通知は，いずれ必ず受け取られる．決済代行サービスが受け取りの確認まで通知を送り直すことと，ECショップの通知の受信処理が止まらないことを前提にする．(性質：livePaidOrderSettles)
```

```quint
  // 支払いを済ませ，まだ確定も返金もされていない注文．
  def unsettled(o: str): bool = charges.get(o) > refunds.get(o) and orderStatus.get(o) != Confirmed

  // 状態変数の組．公平性の仮定で使う．
  val vars = (stock, orderStatus, attempts, requests, charges, refunds, paymentRecord, notifications)

  // 時間切れ監視ジョブは，決済待ちの注文があれば，いずれ必ず動く．
  temporal expireIsFair = ORDERS.forall(o => weakFair(expire(o), vars))

  // 決済代行サービスが送った通知は，いずれ必ず受け取られる．
  temporal notificationIsFair =
    ORDERS.forall(o => Set(Success, Failure).forall(r => weakFair(receiveNotification(o, r), vars)))

  // 注文は，いつまでも決済待ちのままにはならない．
  temporal liveNoEndlessAwaiting =
    expireIsFair implies
      ORDERS.forall(o => always(orderStatus.get(o) == AwaitingPayment implies eventually(orderStatus.get(o) != AwaitingPayment)))

  // 支払いを済ませた注文は，いずれ確定するか返金される．
  temporal livePaidOrderSettles =
    (expireIsFair and notificationIsFair) implies
      ORDERS.forall(o => always(unsettled(o) implies eventually(not(unsettled(o)))))
```

状態遷移図はIteration 3から変わらない．

```text
$ mise run verify iterations/iteration-4/exercise
[install] $ pnpm install --frozen-lockfile
✓ Lockfile passes supply-chain policies (verified 56m ago)
Lockfile is up to date, resolution step is skipped
Done in 21ms using pnpm v12.6.0
[verify] $ node tools/check.ts iterations/iteration-4/exercise
ok  Quintの評価器とApalache

iterations/iteration-4/exercise
ok  quint typecheck
ok  quint test
ok  性質名の照合
ok  quint verify
ok  quint verify(時相論理の性質)
ok  状態遷移図
Finished in 84.27s
```

## 4-7 振り返り

1. 時間切れ監視ジョブの公平性は，ジョブを定期的に動かし，止まったら検知して再起動する運用で実現する．
   通知の公平性は，決済代行サービスの再送の約束(API仕様で確かめる)と，受信処理の監視で実現する．
2. テストにはできなかった．「いずれ」は有限の手順では確かめられないからである．
3. 決済代行サービスが依頼を必ず処理すると仮定すると，決済代行サービスが応答しない場合を検査しなくなる．
   模範解答では，その場合は時間切れで決着するので，その仮定は不要である．必要のない仮定は加えない．
4. 状態遷移図は変わらなかった．Iteration 4は，仕様の振る舞いを変えず，前提と性質を加えた．

## 4-8 発展課題

時間切れのあとの成功の通知で何もしないと，時間切れの注文に課金されたまま，返金されない．
`livePaidOrderSettles`は，公平性をすべて仮定しても，成功の通知を受け取ったあとに止まり続ける反例を示す．
これは，「支払った顧客が，お金と商品のどちらも受け取れない」ことを意味する．
Iteration 2で返金を決めたことが，Iteration 4の活性によって裏付けられる．

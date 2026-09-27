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

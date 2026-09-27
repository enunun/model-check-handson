// エレベーターの扉と移動の仕様(docs/method.mdの例)．
module elevator {
  type Door = Open | Closed
  type Motion = Stopped | Moving

  var door: Door
  var motion: Motion

  action init = all {
    door' = Closed,
    motion' = Stopped,
  }

  action openDoor = all {
    door' = Open,
    motion' = motion,
  }

  action closeDoor = all {
    door' = Closed,
    motion' = motion,
  }

  // 要求: 移動を始めるときは，扉が閉まっている．
  action startMoving = all {
    door == Closed,
    motion == Stopped,
    door' = door,
    motion' = Moving,
  }

  action stop = all {
    motion == Moving,
    door' = door,
    motion' = Stopped,
  }

  action step = any { openDoor, closeDoor, startMoving, stop }

  // 要求: 移動中は扉が開かない．
  val invDoorClosedWhileMoving = motion == Moving implies door == Closed
}

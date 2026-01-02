# iPhone→Watch 链路要点（给开发）
- iOS 端优先使用：
  HKHealthStore().startWatchApp(with: HKWorkoutConfiguration(), completion:)
  失败则使用 WCSession 发送 START_WORKOUT 兜底。
- watchOS 端：
  - HKWorkoutSession + HKLiveWorkoutBuilder 开始采集
  - 结束时 finish 并保存 HKWorkout
  - 用 WCSession 将 workout.uuid 回传 iOS 绑定到 Session.healthWorkoutUUID
- 训练中通过 WCSession 推送：
  当前动作名 / 当前组序号 / 总组数（用于手表端显示）


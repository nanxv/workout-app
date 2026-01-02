# TASKS_M1_CHECKLIST — Silent Gym (M1: iPhone→Watch→Health 闭环)

## P0｜真机闭环（必须先过）
- [ ] 统一命名：将 **Slient** 全部改为 **Silent**（目录、scheme、Display Name）
- [ ] Target 归属：共享管理器文件均勾选到正确 target（iOS / watchOS）
- [ ] iOS Capabilities：HealthKit（Share+Update），（可选）Background → HealthKit
- [ ] watchOS Capabilities：HealthKit + Background → Workout Processing
- [ ] iOS Info.plist：添加  
  - NSHealthShareUsageDescription  
  - NSHealthUpdateUsageDescription  
  - NSCalendarsUsageDescription
- [ ] iPhone→Watch 启动：优先 `HKHealthStore.startWatchApp(with:)`，失败用 WCSession 兜底
- [ ] Watch Workout：`HKWorkoutSession + HKLiveWorkoutBuilder` start→stop→finish→保存 HKWorkout
- [ ] 回传 UUID：watch 将 `workout.uuid` 通过 WCSession 回传；iOS 绑定到 `Session.healthWorkoutUUID`
- [ ] Rest Timer 时间戳校正：`expectedEnd = now + seconds`，前后台切换校正
- [ ] 拒权兜底：Health/Calendar 任一拒绝时不崩，有引导页

**P0 验收**
1) iPhone 点"开始训练"→ Watch 立刻进入 workout（计时/心率可见）  
2) iPhone 点"结束训练"→ Health 出现一次"力量训练"；History 标记"已同步 Health（UUID）"  
3) 切后台 30s 返回，倒计时准确扣 30s

---

## P1｜一周内完成
- [ ] History/Progress 显示同步状态（Health/Calendar ✅/❌）并提供"一键重试"
- [ ] 训练结束 → `EKEventEditViewController` 添加到日历；保存 `eventIdentifier`
- [ ] NRC 跑步导入（via HealthKit）  
  - 读取 `HKWorkoutType.workoutType()` 过滤 `activityType == .running`  
  - 识别 `sourceRevision.source.name/bundleIdentifier` 标注 Nike Run Club  
  - `ExternalWorkout` 以 `uuid` 去重缓存（首次拉近 90 天，后续增量）  
  - UI：History 增加 **Cardio(Health)**；Progress 增加"周 Running 次数/时长/距离"
  - 首次进入 Cardio 页弹"开启 NRC→健康同步"的引导

**P1 验收**
- 开启 NRC→健康同步后，Cardio 列表可见 NRC 跑步（来源显示）；未授权/未同步时有引导且不崩  
- 日历事件保存成功并可在系统日历查看

---

## P2｜体验与工程质量
- [ ] 训练页顶部状态点：Watch 连接、Health 授权（绿/黄/灰）
- [ ] CI：GitHub Actions 成功编译 iOS + watchOS（xcodebuild）
- [ ] 单测：`RestTimerManager`（前后台校正）、`SessionCoordinator`（完成一组→休息→延长/跳过）

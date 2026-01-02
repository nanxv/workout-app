# Silent Gym — MVP 功能测试规范（Spec v1.0）

## 0. 范围（Scope）

* iPhone 开始/结束训练 → Apple Watch 自动开始/结束 workout，并写入 Health（力量训练）
* 训练中：逐组记录（reps/RIR）、组间计时器（可延长/跳过/后台不漂）
* 训练结束：是否添加到日历（EventKitUI）
* 从 Apple 健康导入 NRC 的跑步（只读展示统计）
* History/Progress：Health/Calendar 同步状态可见与重试
* 权限拒绝/断连等异常兜底（不影响本地记录）

## 1. 测试环境

* 设备：
  * iPhone（iOS 17.x 或 18.x）各 1 台
  * Apple Watch（watchOS 10.x 或 11.x）各 1 只
* 构建：当前主分支最新提交（确保 iOS & watchOS targets 可构建运行）
* 账号：无需登录；Health/Calendar 权限按用例设置
* 应用：仓库名 `workout-app`（工程名建议为 `Silent Gym`）

## 2. 前置条件（Pre-flight）

* iPhone 与 Apple Watch 已配对，均可正常安装、运行
* Xcode 中 iOS/Watch targets 已启用 Capabilities：
  * iOS：HealthKit（Share+Update）/（可选）Background→HealthKit
  * watchOS：HealthKit、Background→Workout Processing
* iOS Info.plist 含：`NSHealthShareUsageDescription`、`NSHealthUpdateUsageDescription`、`NSCalendarsUsageDescription`
* App 内已有一个 Routine（如 Day A，含 2–3 个动作）

## 3. 测试矩阵（Matrix）

| 维度   | 覆盖                                          |
| ---- | ------------------------------------------- |
| 系统版本 | iOS 17 / iOS 18；watchOS 10 / 11             |
| 权限   | Health 允许/拒绝；Calendar 允许/拒绝                 |
| 网络   | 在线 / 飞行模式                                   |
| 前后台  | 切后台 30–120s / 锁屏                            |
| 异常   | Watch 断连 / startWatchApp 失败 / WCSession 不可达 |
| 业务   | 仅 iPhone 训练；iPhone+Watch 闭环；NRC 导入          |

## 4. 用例一览（可逐条执行）

**优先级说明**：P0=必须通过；P1=本周内通过；P2=增强项。
每条用例执行后记录：**结果(Pass/Fail)**、**截图**、**日志摘录**。

### A. 基础/仅 iPhone

**TC-A01（P0）** 仅 iPhone 训练记录

* 步骤：打开 App→选 Day A→开始→完成1组(reps/RIR)→自动出 RestTimer→结束训练
* 期望：UI 无异常；History 出现该 Session；Health 标记❌（无手表）；App 不崩
* 备注：验证最小闭环（本地）

**TC-A02（P0）** RestTimer 后台校正

* 步骤：开始训练→完成一组触发计时器→切后台 30s→回来
* 期望：剩余时长≈原值-30s；可 +30s/跳过；无时间漂移

**TC-A03（P1）** 日历写入（允许）

* 步骤：训练结束→弹窗"添加到日历？"→进入编辑器保存→打开系统日历查看
* 期望：事件存在；时间=训练 start/end；History 中 Calendar 标记✅

**TC-A04（P1）** 日历拒绝权限

* 步骤：系统设置关闭日历权限→结束训练→尝试添加
* 期望：App 不崩，出现引导/提示；History 中 Calendar 标记❌

### B. iPhone + Watch 真机闭环

**TC-B01（P0）** iPhone→Watch 自动开始

* 步骤：iPhone 点"开始训练"
* 期望：Watch 立即进入 workout（计时/心率显示），iPhone 侧可正常记录组

**TC-B02（P0）** iPhone 结束→Watch 停止并写入 Health

* 步骤：iPhone 点"结束训练"
* 期望：Watch 自动停止；健康 App→锻炼 出现"力量训练"；History 中该 Session 标记 Health✅（UUID 绑定）

**TC-B03（P0）** startWatchApp 失败→WC 兜底

* 步骤：制造 startWatchApp 失败场景（如临时关闭允许）→再次开始训练
* 期望：WCSession 兜底触发 START_WORKOUT 成功；Watch 仍能进入 workout

**TC-B04（P1）** Watch 断连/中途离腕

* 步骤：训练中将 Watch 移除手腕（触发锁定）或断开连接→继续操作
* 期望：App 有状态提示；允许仅在 iPhone 侧继续记录；结束后不会崩溃

### C. Health 权限

**TC-C01（P0）** 写入被拒绝

* 步骤：健康写入权限拒绝→iPhone+Watch 正常开始/结束
* 期望：App 不崩；结束后 Health 无记录；History 标记 Health❌，并提供引导

**TC-C02（P1）** 写入被允许（回归）

* 步骤：允许写入→重复 B01/B02
* 期望：Health 有记录；History Health✅

### D. NRC 跑步导入（via Health）

**TC-D01（P1）** NRC→Health 已开启，同步成功

* 步骤：用 NRC 跑 1–2 分钟→打开 App→History 的 Cardio 分段
* 期望：列表显示该次跑步；来源显示 Nike Run Club；Progress 周统计更新

**TC-D02（P1）** 未开启或无权限

* 步骤：关闭 NRC→Health 同步或拒绝读取→进入 Cardio
* 期望：页面提示引导，App 不崩；空态正确

**TC-D03（P2）** 较旧数据导入去重

* 步骤：手动向 Health 注入两条时间相近的 NRC 跑步（或模拟）→导入
* 期望：以 uuid 去重，不重复展示

### E. History/Progress 可见态 + 重试

**TC-E01（P1）** Health/Calendar 状态可见

* 步骤：完成一次写入成功的训练 & 一次写入失败的训练
* 期望：列表/详情出现✅/❌标记，失败项有"重试"按钮

**TC-E02（P1）** 重试写入成功

* 步骤：对失败项执行重试（Health 或 Calendar）
* 期望：变为✅；状态及时刷新

### F. 稳定性与性能

**TC-F01（P1）** 长时训练（>30min）

* 步骤：模拟计时运行 30–45 分钟（可减少训练动作输入）
* 期望：计时稳定、无内存暴涨、不卡顿

**TC-F02（P2）** 中断场景

* 步骤：训练中接来电/切应用/锁屏若干次
* 期望：状态一致；RestTimer 正确；不出现"多计时器"现象

### G. 文案与状态指示

**TC-G01（P2）** 顶部状态点（Watch/Health）

* 步骤：分别在授权/未授权、连接/未连接场景观察
* 期望：绿/黄/灰切换正确；与真实状态吻合

---

## 5. 关键观察点 & 日志采集

* iOS 端：
  * `startWatchApp(with:)` 成功/失败与 error
  * WCSession reachability & 消息 START/STOP/WORKOUT_SAVED
  * RestTimer：`expectedEnd` 与 `remaining` 打点
  * Calendar：事件保存结果与 `eventIdentifier`
* watchOS 端：
  * `HKWorkoutSession` 状态变迁（configured→running→ended）
  * `finishWorkout` 返回的 `workout.uuid`
  * 发送回传消息成功/失败

**问题排查快速判断**

* Watch 无反应：先看 `startWatchApp` 的 error，再看 WCSession 是否 reachable
* Health 无记录：watch 是否真正 `finishWorkout`；写入权限是否开启
* 计时漂移：是否用时间戳校正；前后台切换是否校正
* NRC 不显示：Health 中是否有 NRC 跑步；读取权限是否允许；时间窗口过滤是否覆盖

---

## 6. 验收标准（Exit Criteria）

* 所有 **P0 用例 100% 通过**
* P1 用例通过率 ≥ 90%，未通过项须有明确修复计划或暂缓理由
* 无崩溃、无数据损坏；长时测试无明显泄漏或计时异常
* Health 写入/日历写入/导入 NRC 在至少一组"允许权限"的真实设备上验证通过

---

## 7. 测试执行顺序建议

### 第一轮：基础功能（P0）
1. TC-A01（仅 iPhone 训练）
2. TC-A02（RestTimer 后台校正）
3. TC-B01（Watch 自动开始）
4. TC-B02（Watch 停止并写入 Health）
5. TC-B03（startWatchApp 失败兜底）
6. TC-C01（Health 权限拒绝）

### 第二轮：集成功能（P1）
7. TC-A03（日历写入）
8. TC-A04（日历拒绝）
9. TC-C02（Health 允许回归）
10. TC-D01（NRC 导入）
11. TC-D02（NRC 未开启）
12. TC-E01（状态可见）
13. TC-E02（重试功能）

### 第三轮：稳定性（P1/P2）
14. TC-F01（长时训练）
15. TC-F02（中断场景）
16. TC-G01（状态点）
17. TC-B04（Watch 断连）
18. TC-D03（去重）

---

## 8. 测试数据准备

### 训练计划
- Day A：俯卧撑（3组）、深蹲（3组）、平板支撑（3组）
- Day B：引体向上（3组）、箭步蹲（3组）、Burpee（3组）

### NRC 数据
- 在 NRC 中完成至少 1 次跑步（确保已同步到 Apple 健康）

### 权限组合
- 组合1：Health 允许、Calendar 允许
- 组合2：Health 拒绝、Calendar 允许
- 组合3：Health 允许、Calendar 拒绝
- 组合4：Health 拒绝、Calendar 拒绝


# Milestone 1 整改清单 - 真机验收

## P0 立刻执行（跑通真机：iPhone→Watch→Health 闭环）

### ✅ 1. 统一更名与 Target 归属

**任务**：将 **Slient** 全部更名为 **Silent**（工程名、scheme、目录、app display name）

**操作步骤**：
1. 在 Xcode 中，选择项目文件（最顶部）
2. 选择项目（不是 target），在 **Project Name** 中修改为 "Silent Gym"
3. 选择 **Slient Gym** target，修改：
   - **Display Name**: "Silent Gym"
   - **Product Name**: "Silent Gym"
4. 选择 **Slient Gym Watch App** target，修改：
   - **Display Name**: "Silent Gym"
   - **Product Name**: "Silent Gym Watch App"
5. 重命名目录（可选，或保持目录名，只改显示名）：
   - `Slient Gym` → `Silent Gym`
   - `Slient Gym Watch App` → `Silent Gym Watch App`
6. 检查 Scheme 名称：Product > Scheme > Manage Schemes，确保名称正确

**Target Membership 检查**：
- 打开每个共享 Manager 文件，在 File Inspector 中检查 Target Membership：
  - `WatchConnectivityManager.swift` → ✅ iOS, ✅ watchOS
  - `WatchWorkoutManager.swift` → ✅ watchOS only
  - `WatchWorkoutLauncher.swift` → ✅ iOS only
  - `SessionCoordinator.swift` → ✅ iOS only
  - `WatchMessage.swift` → ✅ iOS, ✅ watchOS

**通过标准**：
- [ ] Xcode "Build For Running" iOS target 能直接编译
- [ ] Xcode "Build For Running" watchOS target 能直接编译
- [ ] 运行到真机不崩
- [ ] App 显示名称为 "Silent Gym"

---

### ✅ 2. Capabilities 与 Info.plist（两端）

#### iOS Capabilities

**操作步骤**：
1. 选择 **Silent Gym** target
2. 切换到 **Signing & Capabilities**
3. 点击 **+ Capability**
4. 添加 **HealthKit**
5. 在 HealthKit 配置中，确保勾选：
   - ✅ Share (写入)
   - ✅ Update (更新)

#### watchOS Capabilities

**操作步骤**：
1. 选择 **Silent Gym Watch App** target
2. 切换到 **Signing & Capabilities**
3. 点击 **+ Capability**
4. 添加 **HealthKit**
5. 添加 **Background Modes**
6. 在 Background Modes 中勾选：
   - ✅ Workout Processing

#### iOS Info.plist 权限描述

**操作步骤**：
1. 选择 **Silent Gym** target
2. 切换到 **Info** 标签
3. 在 **Custom iOS Target Properties** 中，点击 **+** 添加：

| Key | Type | Value |
|-----|------|-------|
| `Privacy - Health Share Usage Description` | String | `我们需要访问您的健康数据以读取跑步记录和心率信息。` |
| `Privacy - Health Update Usage Description` | String | `我们需要写入训练数据到健康应用，包括训练时长、心率等信息。` |
| `Privacy - Calendars Usage Description` | String | `我们需要访问您的日历来添加训练记录。` |

**通过标准**：
- [ ] 拒绝 HealthKit 权限不会崩
- [ ] 拒绝 Calendar 权限不会崩
- [ ] 有清晰引导（如何前往设置开启）
- [ ] 权限请求对话框正常显示

---

### ✅ 3. iPhone→Watch 自动开/关 + Health 写入（真机验收）

**代码状态**：✅ 已完成
- `WatchWorkoutLauncher.startWatchWorkout()` 已实现
- WCSession 兜底机制已添加
- `WatchWorkoutManager` 已实现保存和回传 UUID

**验证步骤**：
1. 确保 iPhone 和 Apple Watch 已配对并连接
2. 在 iPhone 上运行应用
3. 选择 Routine，点击"开始训练"
4. 观察：
   - [ ] Watch 立刻显示"正在训练"（有计时/心率）
   - [ ] iPhone 上训练界面正常
5. 完成一组动作，记录数据
6. 点击"结束训练"
7. 观察：
   - [ ] Watch 停止训练
   - [ ] 打开 iPhone **健康 App → 浏览 → 锻炼**
   - [ ] 能看到一条"力量训练"记录
   - [ ] 记录的开始/结束时间正确
8. 在应用的 **History** 中：
   - [ ] 该 Session 显示"已同步 Health"
   - [ ] 有 UUID 标记

**通过标准**：
- [ ] iPhone 点"开始训练" → Watch 立刻进入 workout
- [ ] iPhone 点"结束训练" → Watch 停止并在健康 App 出现"力量训练"
- [ ] History 中该 Session 标记"已同步 Health（UUID 已绑定）"

---

### ✅ 4. Rest Timer 防漂移（时间戳校正）

**代码状态**：✅ 已完成
- `RestTimerManager` 已使用 `expectedEnd` 时间戳
- 已监听 `UIApplication.didBecomeActiveNotification`
- 已使用 `DispatchSourceTimer` 提高精度

**验证步骤**：
1. 开始训练，完成一组动作
2. 休息计时器启动（例如 90 秒）
3. 观察倒计时正常
4. 按 Home 键切到后台
5. 等待 30 秒
6. 切回应用
7. 观察：
   - [ ] 剩余时间准确扣除了 30 秒
   - [ ] 计时器继续正常运行

**通过标准**：
- [ ] 切后台 30 秒，回来后剩余时间准确扣除 30 秒
- [ ] 多次延长/跳过不卡顿
- [ ] 计时器精度准确

---

## P1 本周内完成（可视化与 NRC 导入）

### 5. History/Progress 同步状态可见 & 重试

**任务**：在 Session 列表/详情显示：Health ✅/❌、Calendar ✅/❌；失败提供"重试"按钮

**实现要点**：
- Session 列表项显示图标：
  - Health 已同步：🟢 或 ✅
  - Health 未同步：⚪ 或 ❌
  - Calendar 已添加：📅 或 ✅
  - Calendar 未添加：⚪ 或 ❌
- Session 详情页：
  - 显示同步状态
  - 如果失败，提供"重试写入 Health"或"重试创建日历"按钮

**通过标准**：
- [ ] 用户一眼能看到同步结果
- [ ] 失败可一键重试
- [ ] 重试后状态更新

---

### 6. 日历写入走 EventKitUI

**代码状态**：✅ 已实现
- `CalendarManager.createEventForSession()` 已使用 `EKEventEditViewController`
- 训练结束已触发日历添加

**验证步骤**：
1. 完成一次训练
2. 训练结束时应弹出日历编辑界面
3. 观察：
   - [ ] 标题默认：`训练 - <RoutineName>`
   - [ ] 时间：Session start/end
   - [ ] 备注：总组数/总 reps/平均 RIR
4. 点击"保存"
5. 打开 **日历 App**
6. 观察：
   - [ ] 能看到训练事件
   - [ ] 开始时间 = 训练开始
   - [ ] 结束时间 = 训练结束

**通过标准**：
- [ ] 拒绝不影响训练保存
- [ ] 同意后在日历能看到事件
- [ ] 事件时间正确

---

### 7. NRC 跑步导入（经由 Apple 健康）

**代码状态**：✅ 已实现基础功能
- `HealthImportManager` 已实现
- History 已有 Cardio 分段
- Progress 已有 Cardio 统计

**需要完善**：
- [ ] 首次进入 Cardio 页弹引导（如何在 iOS 设置里打开 NRC→健康同步）
- [ ] 来源识别优化
- [ ] 去重逻辑验证

**验证步骤**：
1. 确保 Nike Run Club 已与 Apple 健康同步
2. 在 NRC 中完成一次跑步
3. 在应用中：
   - [ ] 进入 **History** → 切换到 **Cardio** 分段
   - [ ] 能看到 NRC 跑步记录
   - [ ] 显示来源为 "Nike Run Club"
4. 进入 **Progress**：
   - [ ] 能看到 Running 次数/时长/距离统计

**通过标准**：
- [ ] 已开启 NRC→健康同步时，能看到 NRC 产生的跑步记录
- [ ] 显示来源名称
- [ ] 未授权/未同步时给出引导，不崩

---

## P2 体验与工程质量

### 8. 训练页"状态点"

**任务**：顶部增加 Watch 连接状态、Health 授权状态点（绿/黄/灰）

**实现要点**：
- Watch 状态：
  - 🟢 已连接且可达
  - 🟡 已配对但不可达
  - ⚪ 未配对/未安装
- Health 授权状态：
  - 🟢 已授权（读写）
  - 🟡 部分授权（只读）
  - ⚪ 未授权

**通过标准**：
- [ ] 在开始训练前即可预判是否能成功拉起手表/写入健康
- [ ] 状态点清晰易懂

---

### 9. CI 与基础测试

**GitHub Actions**：

创建 `.github/workflows/build.yml`：

```yaml
name: iOS-watchOS Build
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: '15.2' }
      - name: Build iOS
        run: xcodebuild -project "Silent Gym.xcodeproj" -scheme "Silent Gym" -sdk iphonesimulator -configuration Debug build | xcpretty
      - name: Build watchOS
        run: xcodebuild -project "Silent Gym.xcodeproj" -scheme "Silent Gym Watch App" -sdk watchsimulator -configuration Debug build | xcpretty
```

**单测**：
- `RestTimerManagerTests`：前后台切换校正
- `SessionCoordinatorTests`：完成一组→自动启休→延长/跳过的状态转移

---

## 验收脚本

### 场景1（仅 iPhone）
- [ ] 拒绝 Health/Calendar 权限 → 不崩
- [ ] 能完整记录 Day A
- [ ] Rest 计时准确

### 场景2（iPhone+Watch 真机）
- [ ] 点开始 → Watch 即刻进入 workout
- [ ] 点结束 → Health 出现"力量训练"
- [ ] History 显示已同步

### 场景3（NRC 导入）
- [ ] 在 NRC 跑一次（确保已与健康同步）
- [ ] Cardio 分段出现记录，来源显示 Nike Run Club
- [ ] Progress 汇总更新

### 场景4（日历）
- [ ] 训练结束弹窗 → 编辑 → 保存
- [ ] 日历出现事件
- [ ] History 标示 Calendar ✅

---

## Info.plist 文案模板

### iOS Info.plist 权限描述（中文）

```xml
<key>NSHealthShareUsageDescription</key>
<string>我们需要访问您的健康数据以读取跑步记录和心率信息。</string>

<key>NSHealthUpdateUsageDescription</key>
<string>我们需要写入训练数据到健康应用，包括训练时长、心率等信息。</string>

<key>NSCalendarsUsageDescription</key>
<string>我们需要访问您的日历来添加训练记录。</string>
```

### iOS Info.plist 权限描述（英文）

```xml
<key>NSHealthShareUsageDescription</key>
<string>We need access to your health data to read running records and heart rate information.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>We need to write workout data to the Health app, including workout duration and heart rate information.</string>

<key>NSCalendarsUsageDescription</key>
<string>We need access to your calendar to add workout records.</string>
```

---

## Health/Calendar 权限引导文案

### HealthKit 权限被拒绝时的引导

**标题**：需要健康权限

**内容**：
```
为了记录您的训练数据并同步到 Apple 健康，我们需要访问健康数据。

请按以下步骤开启：
1. 打开 iPhone 设置
2. 进入"隐私与安全性"
3. 选择"健康"
4. 找到"Silent Gym"
5. 开启"允许读取数据"和"允许写入数据"
```

### Calendar 权限被拒绝时的引导

**标题**：需要日历权限

**内容**：
```
为了将训练记录添加到您的日历，我们需要访问日历。

请按以下步骤开启：
1. 打开 iPhone 设置
2. 进入"隐私与安全性"
3. 选择"日历"
4. 找到"Silent Gym"
5. 开启"允许访问日历"
```

---

## 下一步

1. 完成 P0 任务（命名、Capabilities、Info.plist）
2. 真机测试 iPhone→Watch→Health 闭环
3. 完善 P1 任务（可视化、引导）
4. 添加 P2 任务（状态点、CI、测试）


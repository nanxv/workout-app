# Milestone 1 设置指南

## 已完成的工作

✅ 创建了所有必要的代码文件：
- WatchConnectivity 管理器（iOS 和 watchOS 共享）
- WatchWorkoutManager（watchOS 端，处理 HealthKit workout）
- WatchWorkoutLauncher（iOS 端，启动 watch app）
- SessionCoordinator 已更新以支持 watch 集成
- watchOS app 入口和 UI

## 需要在 Xcode 中完成的步骤

### 1. 添加 watchOS Target

1. 在 Xcode 中打开项目
2. 选择项目文件（Silent Gym.xcodeproj）
3. 点击左下角的 "+" 按钮添加新 Target
4. 选择 **watchOS > App**
5. 配置：
   - Product Name: `Silent Gym Watch App`
   - Bundle Identifier: `ZC.POB.Silent-Gym.watchkitapp`
   - Language: Swift
   - Interface: SwiftUI
   - Include Notification Scene: 可选

### 2. 配置 watchOS Target

#### 2.1 添加文件到 watchOS Target

将以下文件添加到 watchOS target（在 File Inspector 中勾选 target membership）：

**必须添加到 watchOS target：**
- `Silent Gym Watch App/App/Silent_GymWatchApp.swift`
- `Silent Gym Watch App/Data/Health/WatchWorkoutManager.swift`
- `Silent Gym Watch App/Features/Workout/WorkoutView.swift`
- `Silent Gym/Shared/DTO/WatchMessage.swift`
- `Silent Gym/Data/WatchConnectivity/WatchConnectivityManager.swift`（共享）

**可选（如果需要共享数据模型）：**
- 如果需要 watchOS 也能访问 SwiftData，需要添加数据模型文件

#### 2.2 配置 Info.plist

1. 在 watchOS target 中添加 `Info.plist` 文件
2. 确保包含 HealthKit 权限描述：
   - `NSHealthShareUsageDescription`
   - `NSHealthUpdateUsageDescription`
   - `UIBackgroundModes` 包含 `workout-processing`

#### 2.3 配置 Capabilities

在 watchOS target 的 **Signing & Capabilities** 中：

1. 点击 "+ Capability"
2. 添加 **HealthKit**
3. 确保勾选：
   - Workout Processing（后台处理）
   - Workout Route（如果需要 GPS）

#### 2.4 配置 iOS Target

在 iOS target 的 **Signing & Capabilities** 中：

1. 添加 **HealthKit** capability
2. 确保勾选：
   - Workout Processing

### 3. 配置 Bundle Identifier

确保 watchOS app 的 Bundle Identifier 格式为：
```
ZC.POB.Silent-Gym.watchkitapp
```

watchOS extension（如果有）应该是：
```
ZC.POB.Silent-Gym.watchkitapp.watchkitextension
```

### 4. 添加依赖

#### watchOS Target 需要：
- `HealthKit.framework`
- `WatchConnectivity.framework`
- `WatchKit.framework`

这些通常会自动链接，但请检查 **Build Phases > Link Binary With Libraries**

### 5. 配置 Scheme

1. 在 Xcode 中，选择 Scheme: `Silent Gym Watch App`
2. 确保选择了正确的 watchOS 设备或模拟器
3. 运行 iOS app 时，确保 watchOS app 也会自动安装

## 测试步骤

### 1. 基本功能测试

1. 在 iPhone 上运行 iOS app
2. 确保 Apple Watch 已配对并连接
3. 在 iOS app 中选择一个 Routine 开始训练
4. 检查：
   - watchOS app 是否自动启动
   - watchOS app 是否显示训练计时
   - 心率数据是否显示（如果有）

### 2. 状态同步测试

1. 在 iOS app 中完成一组动作
2. 检查 watchOS app 是否更新当前动作和组数信息

### 3. HealthKit 写入测试

1. 完成一次训练
2. 在 iPhone 上打开 **健康** app
3. 检查是否能看到新的力量训练记录
4. 验证开始/结束时间是否正确

### 4. 错误处理测试

1. 断开 watch 连接
2. 尝试开始训练
3. 验证 iOS app 不会崩溃，并显示适当的提示

## 常见问题

### Q: watchOS app 没有自动启动

**A:** 检查：
1. watchOS app 是否已安装到 watch 上
2. HealthKit 权限是否已授予
3. `startWatchApp(with:)` 是否成功调用
4. 查看 Xcode console 中的错误信息

### Q: HealthKit 权限被拒绝

**A:** 
1. 在 iOS 设置 > 健康 > 数据访问与设备中检查权限
2. 确保 Info.plist 中有正确的权限描述
3. 重新请求权限（可能需要删除 app 重新安装）

### Q: WatchConnectivity 消息没有收到

**A:**
1. 确保 watch 和 iPhone 已连接
2. 检查 `WCSession.isReachable` 状态
3. 使用 `transferUserInfo` 作为后备方案（即使 watch 不可达也会传递）

### Q: 编译错误：找不到 HealthKit

**A:**
1. 确保在正确的 target 中（watchOS 或 iOS）
2. 检查 Framework Search Paths
3. 确保 Deployment Target 设置正确（iOS 8.0+, watchOS 2.0+）

## 下一步

完成 Milestone 1 后，可以继续：
- **Milestone 2**: Calendar 集成
- **Milestone 3**: NRC 跑步导入
- **Milestone 4**: OpenAI Function Calling

## 代码结构

```
Silent Gym/
├── Shared/
│   └── DTO/
│       └── WatchMessage.swift          # 共享消息协议
├── Data/
│   ├── WatchConnectivity/
│   │   └── WatchConnectivityManager.swift  # iOS/watchOS 共享
│   └── Health/
│       └── WatchWorkoutLauncher.swift   # iOS 端
└── Silent Gym Watch App/
    ├── App/
    │   └── Silent_GymWatchApp.swift     # watchOS app 入口
    ├── Data/
    │   └── Health/
    │       └── WatchWorkoutManager.swift # watchOS workout 管理
    └── Features/
        └── Workout/
            └── WorkoutView.swift         # watchOS UI
```

## 注意事项

1. **HealthKit 权限**：首次使用时需要用户授权，确保有清晰的说明
2. **Watch 连接**：watch 可能不在范围内，需要优雅降级
3. **后台处理**：watchOS app 需要在后台处理 workout，确保配置正确
4. **数据同步**：使用 WatchConnectivity 确保 iOS 和 watchOS 状态同步


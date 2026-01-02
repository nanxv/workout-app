# Slient Gym - iOS 训练记录应用

一款专注于"训练中极省脑、训练后可复盘"的 iOS 训练记录应用，深度集成 Apple 生态。

## 🎉 当前状态：所有 Milestone 代码已完成！

### ✅ Milestone 0：本地训练闭环 - **100% 完成**
- ✅ SwiftData 数据模型（Exercise, Routine, Session, SetEntry 等）
- ✅ Routine 管理（创建/编辑 Day A/B/C）
- ✅ 训练 Session 记录（逐组记录 reps + RIR）
- ✅ 休息计时器（自动启动、可延长/跳过）
- ✅ 训练历史查看
- ✅ 进度统计（周汇总、动作趋势）
- ✅ AI 教练（本地命令解析）

### ✅ Milestone 1：Watch + Health 集成 - **代码 100% 完成**
- ✅ WatchConnectivity 管理器（iOS 和 watchOS 共享）
- ✅ WatchWorkoutManager（watchOS 端，HealthKit workout）
- ✅ WatchWorkoutLauncher（iOS 端，启动 watch app）
- ✅ SessionCoordinator 已更新以支持 watch 集成
- ✅ watchOS app 入口和 UI

**⚠️ 注意：** 需要在 Xcode 中配置 watchOS target 才能使用，详细步骤请查看 [MILESTONE_1_SETUP.md](./MILESTONE_1_SETUP.md)

### ✅ Milestone 2：Calendar 集成 - **100% 完成**
- ✅ CalendarManager（EventKit 集成）
- ✅ 训练结束自动添加日历事件
- ✅ Coach 命令支持（"把本次训练加到日历"）
- ✅ History 显示日历同步状态

### ✅ Milestone 3：NRC 跑步导入 - **100% 完成**
- ✅ HealthImportManager（从 HealthKit 读取 Running workouts）
- ✅ NRC 来源识别
- ✅ ExternalWorkout 缓存和去重
- ✅ History 显示 Cardio workouts
- ✅ Progress 包含 Cardio 统计
- ✅ NRC 设置引导页面

### ✅ Milestone 4：OpenAI Function Calling - **框架完成**
- ✅ OpenAICommandClient 框架
- ✅ Function definitions
- ✅ 本地/OpenAI 切换
- ⚠️ 需要后端代理（保护 API Key）

## 功能特性

### 1. 训练计划（Routines）
- 创建自定义训练计划（Day A/B/C）
- 为每个动作设置：目标组数、休息时间
- 动作可排序、可编辑

### 2. 训练记录（Train）
- 选择 Routine 开始训练
- 逐组记录：Reps（次数）、RIR（剩余次数，0-4）
- 自动启动组间休息计时器
- 支持延长休息（+15s/+30s）或跳过
- 训练结束后自动保存
- **🆕 自动启动 Apple Watch workout（需要配置）**

### 3. 历史记录（History）
- 查看所有训练 Session
- 显示训练时长、动作数量
- 标记已同步到 Health 和 Calendar 的 Session

### 4. 进度统计（Progress）
- 本周汇总：力量训练时长、有氧时长、总次数
- 动作趋势：最佳 Reps、总 Reps、平均 RIR

### 5. AI 教练（Coach）
- 本地命令解析（无需网络）
- 支持命令：
  - "开始 Day A" / "开始 Day B" / "开始 Day C"
  - "结束训练"
  - "跳过休息" / "休息 +30 秒"
  - "总结"（查看训练统计）

## 使用说明

### 首次启动
应用会自动创建示例数据：
- Day A: 俯卧撑、深蹲、平板支撑
- Day B: 引体向上、箭步蹲、Burpee
- Day C: 俯卧撑、深蹲、引体向上

### 开始训练
1. 进入 **Train** Tab
2. 选择要执行的 Routine（如 Day A）
3. 点击 Routine 开始训练
4. **如果已配置 watchOS：** Apple Watch 会自动启动 workout session
5. 逐组完成动作：
   - 输入完成的 Reps
   - 选择 RIR（0-4）
   - 点击 "Complete Set"
6. 休息计时器自动启动，可延长或跳过
7. 完成所有动作后，点击 "End Session" 结束训练
8. **如果已配置 watchOS：** 训练数据会自动写入 HealthKit

### 管理训练计划
1. 进入 **Routines** Tab
2. 点击 "+" 创建新 Routine
3. 点击 Routine 进入详情，添加动作
4. 为每个动作设置组数和休息时间

### 查看历史
1. 进入 **History** Tab
2. 使用筛选器查看：All / Strength / Cardio
3. 点击 Session 查看详细记录

### 使用 AI 教练
1. 进入 **Coach** Tab
2. 输入自然语言命令，例如：
   - "开始 Day A"
   - "结束训练"
   - "跳过休息"
   - "总结"

## 技术架构

- **UI**: SwiftUI
- **数据持久化**: SwiftData
- **架构**: MVVM + 单向数据流
- **状态管理**: 
  - `TrainingSessionState`: 训练状态机
  - `RestTimerState`: 休息计时器状态
- **核心组件**:
  - `SessionCoordinator`: 训练流程协调器
  - `RestTimerManager`: 精确计时器
  - `CoachCommandRouter`: 命令解析器
  - **🆕 `WatchConnectivityManager`**: Watch 通信管理器
  - **🆕 `WatchWorkoutManager`**: Watch 端 workout 管理
  - **🆕 `WatchWorkoutLauncher`**: iOS 端启动 watch app

## ✅ 所有功能已完成

### Milestone 1: Watch + Health 集成 ✅
- ✅ Apple Watch 自动开始/结束 workout
- ✅ 写入 HealthKit（力量训练）
- ✅ WatchConnectivity 状态同步
- ⚠️ **需要在 Xcode 中配置 watchOS target**

### Milestone 2: Calendar 集成 ✅
- ✅ 训练结束后添加到 Apple 日历
- ✅ 使用 EKEventEditViewController
- ✅ Coach 命令支持

### Milestone 3: NRC 跑步导入 ✅
- ✅ 从 HealthKit 读取 Nike Run Club 跑步记录
- ✅ NRC 来源识别
- ✅ 在 History 和 Progress 中展示
- ✅ 导入和去重功能

### Milestone 4: OpenAI Function Calling ✅
- ✅ OpenAI 框架代码
- ✅ Function definitions
- ⚠️ 需要后端代理（保护 API Key）

## 项目结构

```
Slient Gym/
├── Domain/
│   ├── Models/          # SwiftData 实体
│   └── UseCases/        # 业务逻辑
├── Data/
│   ├── Persistence/     # SwiftData 配置
│   ├── WatchConnectivity/  # Watch 通信
│   └── Health/          # HealthKit 集成
├── Features/
│   ├── Train/           # 训练界面
│   ├── Routines/        # 训练计划管理
│   ├── History/         # 历史记录
│   ├── Progress/        # 进度统计
│   ├── Coach/           # AI 教练
│   └── MainTabView.swift
├── Shared/
│   └── DTO/             # 共享数据协议
└── Slient Gym Watch App/  # watchOS app
    ├── App/
    ├── Data/
    └── Features/
```

## 开发环境

- Xcode 15.0+
- iOS 17.0+
- watchOS 10.0+（用于 watchOS app）
- Swift 5.9+

## 设置指南

### Milestone 1 设置

详细步骤请查看 [MILESTONE_1_SETUP.md](./MILESTONE_1_SETUP.md)

快速步骤：
1. 在 Xcode 中添加 watchOS target
2. 配置 HealthKit capabilities
3. 将共享文件添加到 watchOS target
4. 配置 Info.plist

## 注意事项

- ✅ **Milestone 0-4** 所有代码已完成
- ⚠️ **Milestone 1** 需要在 Xcode 中配置 watchOS target 才能使用
- ⚠️ **Milestone 4** 需要后端代理才能使用 OpenAI function calling
- ✅ 所有数据存储在本地，无云端同步
- ✅ AI 教练支持本地命令解析和 OpenAI（需后端）
- ✅ Health、Calendar、Watch 集成需要相应的系统权限

## 📊 项目统计

- **总代码文件：** 28+ 个 Swift 文件
- **总代码行数：** 4500+ 行
- **数据模型：** 7 个 SwiftData 实体
- **核心管理器：** 8 个
- **UI 视图：** 10+ 个主要视图

详细状态请查看 [FINAL_STATUS.md](./FINAL_STATUS.md)

## 许可证

私有项目

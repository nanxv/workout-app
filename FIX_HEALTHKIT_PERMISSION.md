# 修复 HealthKit 权限错误

## 错误信息
```
NSHealthUpdateUsageDescription must be set in the app's Info.plist
```

## 快速修复步骤（推荐方法）

### 方法 1：在 Xcode Info 标签中添加（最简单）

1. **打开 Xcode 项目**
2. **选择项目文件**（最顶部的蓝色图标 "Slient Gym"）
3. **选择 "Slient Gym" target**（不是项目，是 target）
4. **切换到 "Info" 标签**
5. **在 "Custom iOS Target Properties" 部分，点击 "+" 按钮添加以下键值对：**

| Key | Type | Value |
|-----|------|-------|
| Privacy - Health Share Usage Description | String | 用于读取并展示你的跑步与训练数据（例如 Nike Run Club 同步到"健康"的记录）。 |
| Privacy - Health Update Usage Description | String | 用于将本应用记录的力量训练写入"健康"。 |
| Privacy - Calendars Usage Description | String | 用于把你的训练记录添加到系统日历。 |

### 方法 2：在 Build Settings 中添加

如果方法 1 不工作，可以尝试：

1. **选择 "Slient Gym" target**
2. **切换到 "Build Settings" 标签**
3. **在搜索框中输入 `INFOPLIST_KEY`**
4. **点击 "+" 按钮添加以下键：**

- **INFOPLIST_KEY_NSHealthShareUsageDescription** = `用于读取并展示你的跑步与训练数据（例如 Nike Run Club 同步到"健康"的记录）。`
- **INFOPLIST_KEY_NSHealthUpdateUsageDescription** = `用于将本应用记录的力量训练写入"健康"。`
- **INFOPLIST_KEY_NSCalendarsUsageDescription** = `用于把你的训练记录添加到系统日历。`

## 验证步骤

1. **清理构建**：`Product > Clean Build Folder` (Shift+Cmd+K)
2. **重新构建**：`Product > Build` (Cmd+B)
3. **运行应用**：点击开始训练，应该不再出现错误

## 注意事项

- 这些权限描述是必需的，iOS 会在首次请求权限时向用户显示
- 描述文字应该清晰说明为什么需要这些权限
- 如果应用被拒绝，可能需要更详细的描述


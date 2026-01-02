# Xcode 配置步骤 - Info.plist 权限设置

## 问题
项目使用自动生成的 Info.plist (`GENERATE_INFOPLIST_FILE = YES`)，所以不能同时存在手动创建的 Info.plist 文件。

## 解决方案：在 Build Settings 中添加权限键

### 步骤 1：打开 Build Settings

1. 在 Xcode 中，选择项目文件（最顶部的蓝色图标）
2. 选择 **Slient Gym** target（不是项目）
3. 切换到 **Build Settings** 标签
4. 在搜索框中输入 `INFOPLIST_KEY`

### 步骤 2：添加 HealthKit 权限

1. 找到 **INFOPLIST_KEY_NSHealthShareUsageDescription**
2. 如果没有，点击 **+** 按钮添加
3. 设置值为：`我们需要访问您的健康数据以读取跑步记录和心率信息。`

### 步骤 3：添加 HealthKit 写入权限

1. 找到 **INFOPLIST_KEY_NSHealthUpdateUsageDescription**
2. 如果没有，点击 **+** 按钮添加
3. 设置值为：`我们需要写入训练数据到健康应用，包括训练时长、心率等信息。`

### 步骤 4：添加 Calendar 权限

1. 找到 **INFOPLIST_KEY_NSCalendarsUsageDescription**
2. 如果没有，点击 **+** 按钮添加
3. 设置值为：`我们需要访问您的日历来添加训练记录。`

## 或者：使用 Info 标签（更简单）

### 方法 2：在 Info 标签中添加

1. 选择 **Slient Gym** target
2. 切换到 **Info** 标签
3. 在 **Custom iOS Target Properties** 部分，点击 **+** 按钮
4. 添加以下键值对：

| Key | Type | Value |
|-----|------|-------|
| Privacy - Health Share Usage Description | String | 我们需要访问您的健康数据以读取跑步记录和心率信息。 |
| Privacy - Health Update Usage Description | String | 我们需要写入训练数据到健康应用，包括训练时长、心率等信息。 |
| Privacy - Calendars Usage Description | String | 我们需要访问您的日历来添加训练记录。 |

## 验证

1. 清理构建：**Product > Clean Build Folder** (Shift+Cmd+K)
2. 重新构建：**Product > Build** (Cmd+B)
3. 检查是否还有错误

## 注意事项

- 如果使用自动生成的 Info.plist，**不要**手动创建 Info.plist 文件
- 所有权限描述必须通过 Build Settings 或 Info 标签添加
- 修改后需要清理构建才能生效


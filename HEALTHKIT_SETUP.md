# HealthKit 权限设置指南

## 问题
应用在请求 HealthKit 写入权限时出现错误：
```
NSHealthUpdateUsageDescription must be set in the app's Info.plist
```

## 解决方案

### 方法 1：使用 Info.plist 文件（推荐）

1. 在 Xcode 中，选择项目文件（Silent Gym.xcodeproj）
2. 选择 **Silent Gym** target
3. 在 **Build Settings** 中搜索 `INFOPLIST_FILE`
4. 设置 `INFOPLIST_FILE` 为 `Silent Gym/Info.plist`
5. 或者直接在项目导航器中右键点击 **Silent Gym** 文件夹，选择 **Add Files to "Silent Gym"...**
6. 选择已创建的 `Info.plist` 文件

### 方法 2：在 Build Settings 中直接设置

如果项目使用自动生成的 Info.plist（`GENERATE_INFOPLIST_FILE = YES`），可以在 Build Settings 中添加：

1. 选择 **Silent Gym** target
2. 在 **Build Settings** 中搜索 `INFOPLIST_KEY`
3. 添加以下键值对：
   - `INFOPLIST_KEY_NSHealthShareUsageDescription` = "我们需要访问您的健康数据以读取跑步记录和心率信息。"
   - `INFOPLIST_KEY_NSHealthUpdateUsageDescription` = "我们需要写入训练数据到健康应用，包括训练时长、心率等信息。"
   - `INFOPLIST_KEY_NSCalendarsUsageDescription` = "我们需要访问您的日历来添加训练记录。"

### 方法 3：在 Xcode 中手动添加

1. 在 Xcode 中，选择项目文件
2. 选择 **Silent Gym** target
3. 切换到 **Info** 标签
4. 点击 **+** 按钮添加以下键：
   - `Privacy - Health Share Usage Description` (NSHealthShareUsageDescription)
   - `Privacy - Health Update Usage Description` (NSHealthUpdateUsageDescription)
   - `Privacy - Calendars Usage Description` (NSCalendarsUsageDescription)
5. 填入相应的描述文字

## 必需的权限描述

### HealthKit 读取权限
```
我们需要访问您的健康数据以读取跑步记录和心率信息。
```

### HealthKit 写入权限
```
我们需要写入训练数据到健康应用，包括训练时长、心率等信息。
```

### Calendar 权限
```
我们需要访问您的日历来添加训练记录。
```

## 验证

设置完成后：
1. 清理构建（Product > Clean Build Folder）
2. 重新构建项目
3. 运行应用
4. 点击开始训练时，应该会弹出权限请求对话框

## 注意事项

- 权限描述必须清晰说明为什么需要这些权限
- 如果修改了权限描述，可能需要删除应用重新安装才能看到新的权限请求
- 在模拟器上测试时，某些权限可能不会弹出，需要在真机上测试


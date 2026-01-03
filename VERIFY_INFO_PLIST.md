# 验证 Info.plist 权限配置

## 问题
即使添加了权限描述，仍然出现错误：
```
NSHealthUpdateUsageDescription must be set in the app's Info.plist
```

## 验证步骤

### 方法 1：在 Xcode 中检查 Info 标签

1. 打开 Xcode
2. 选择项目文件（蓝色图标）
3. 选择 **"Slient Gym"** target（不是项目）
4. 切换到 **"Info"** 标签
5. 在 **"Custom iOS Target Properties"** 中查找以下键：

   - `Privacy - Health Share Usage Description` (NSHealthShareUsageDescription)
   - `Privacy - Health Update Usage Description` (NSHealthUpdateUsageDescription)
   - `Privacy - Calendars Usage Description` (NSCalendarsUsageDescription)

6. **如果这些键不存在，请添加它们**

### 方法 2：检查 Build Settings

1. 选择 **"Slient Gym"** target
2. 切换到 **"Build Settings"** 标签
3. 在搜索框中输入 `INFOPLIST_KEY`
4. 查找以下键：

   - `INFOPLIST_KEY_NSHealthShareUsageDescription`
   - `INFOPLIST_KEY_NSHealthUpdateUsageDescription`
   - `INFOPLIST_KEY_NSCalendarsUsageDescription`

5. **如果这些键不存在，请添加它们**

### 方法 3：检查生成的 Info.plist

构建应用后，检查生成的 Info.plist：

1. 在 Xcode 中：`Product > Build` (Cmd+B)
2. 在 Finder 中打开构建产物：
   - `~/Library/Developer/Xcode/DerivedData/Slient_Gym-*/Build/Products/Debug-iphonesimulator/Slient Gym.app/Info.plist`
3. 打开 Info.plist 文件，检查是否包含：
   - `NSHealthShareUsageDescription`
   - `NSHealthUpdateUsageDescription`
   - `NSCalendarsUsageDescription`

## 如果仍然不工作

### 方案 A：创建手动 Info.plist 文件

1. 在 Xcode 中，右键点击 **"Slient Gym"** 文件夹
2. 选择 **"New File..."**
3. 选择 **"Property List"**
4. 命名为 `Info.plist`
5. 添加以下内容：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSHealthShareUsageDescription</key>
	<string>用于读取并展示你的跑步与训练数据（例如 Nike Run Club 同步到"健康"的记录）。</string>
	<key>NSHealthUpdateUsageDescription</key>
	<string>用于将本应用记录的力量训练写入"健康"。</string>
	<key>NSCalendarsUsageDescription</key>
	<string>用于把你的训练记录添加到系统日历。</string>
</dict>
</plist>
```

6. 在 Build Settings 中设置 `INFOPLIST_FILE` = `Slient Gym/Info.plist`

### 方案 B：在代码中延迟请求权限

如果 Info.plist 配置有问题，可以暂时修改代码，在请求写入权限前先检查权限描述是否存在：

```swift
// 在 WatchWorkoutLauncher.swift 中
func startWatchWorkout(...) {
    // 检查权限描述是否存在
    guard let infoPlist = Bundle.main.infoDictionary,
          let _ = infoPlist["NSHealthUpdateUsageDescription"] as? String else {
        print("Warning: NSHealthUpdateUsageDescription not found in Info.plist")
        // 仍然尝试请求，但可能会失败
    }
    
    // 继续原有逻辑...
}
```

## 常见问题

### Q: 为什么添加了权限描述还是报错？
A: 可能的原因：
1. 权限描述添加到了错误的 target
2. 需要清理构建缓存：`Product > Clean Build Folder` (Shift+Cmd+K)
3. 需要重新构建：`Product > Build` (Cmd+B)
4. 权限描述的值是空的

### Q: 如何确认权限描述已正确添加？
A: 
1. 构建应用
2. 检查生成的 Info.plist 文件
3. 或者运行应用，查看控制台是否有权限相关的日志

### Q: 可以暂时禁用 HealthKit 写入吗？
A: 可以，修改 `WatchWorkoutLauncher.swift`，将 `typesToShare` 改为空数组：
```swift
let typesToShare: Set<HKSampleType> = [] // 暂时不请求写入权限
```


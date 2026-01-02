# 权限引导文案模板

## HealthKit 权限引导

### 权限请求对话框文案

**读取权限**：
```
我们需要访问您的健康数据以读取跑步记录和心率信息。
```

**写入权限**：
```
我们需要写入训练数据到健康应用，包括训练时长、心率等信息。
```

### 权限被拒绝时的引导页面

**标题**：需要健康权限

**正文**：
```
为了记录您的训练数据并同步到 Apple 健康，我们需要访问健康数据。

请按以下步骤开启权限：

1. 打开 iPhone 设置
2. 进入"隐私与安全性"
3. 选择"健康"
4. 找到"Silent Gym"
5. 开启以下权限：
   • 允许读取数据（用于导入跑步记录）
   • 允许写入数据（用于保存训练记录）
```

**按钮**：
- "前往设置"（打开 Settings URL）
- "稍后再说"

---

## Calendar 权限引导

### 权限请求对话框文案

```
我们需要访问您的日历来添加训练记录。
```

### 权限被拒绝时的引导页面

**标题**：需要日历权限

**正文**：
```
为了将训练记录添加到您的日历，我们需要访问日历。

请按以下步骤开启权限：

1. 打开 iPhone 设置
2. 进入"隐私与安全性"
3. 选择"日历"
4. 找到"Silent Gym"
5. 开启"允许访问日历"
```

**按钮**：
- "前往设置"（打开 Settings URL）
- "稍后再说"

---

## NRC 同步引导

### 首次进入 Cardio 页的引导

**标题**：导入 Nike Run Club 跑步记录

**正文**：
```
要查看您的 NRC 跑步记录，需要先在 Nike Run Club 中开启与 Apple 健康的同步。

请按以下步骤设置：

1. 打开 Nike Run Club App
2. 进入"我" → "设置"
3. 找到"健康"或"Health"选项
4. 开启同步以下数据：
   • 训练
   • 心率
   • 距离
   • 活动能量

设置完成后，返回此应用，点击"导入跑步记录"即可。
```

**按钮**：
- "知道了"
- "打开 NRC App"（可选）

---

## Watch 连接引导

### Watch 未连接时的提示

**标题**：Apple Watch 未连接

**正文**：
```
要使用 Watch 自动记录训练，需要：

1. 确保 Apple Watch 已配对并连接
2. 在 Watch 上安装 Silent Gym Watch App
3. 确保 Watch 和 iPhone 在同一 Wi-Fi 或蓝牙范围内

即使没有 Watch，您仍然可以在 iPhone 上正常记录训练。
```

**按钮**：
- "知道了"
- "检查连接状态"

---

## 通用设置 URL

### Swift 代码示例

```swift
// 打开应用设置
if let url = URL(string: UIApplication.openSettingsURLString) {
    UIApplication.shared.open(url)
}

// 打开健康设置（iOS 16+）
if let url = URL(string: "x-apple-health://") {
    UIApplication.shared.open(url)
}
```


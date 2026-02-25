# 📱 部署到真实设备指南

本指南将帮助你将应用安装到真实的 iPhone 和 Apple Watch 上进行测试。

## 📋 前置要求

### 1. Apple 开发者账号
- **免费账号**：可以使用个人 Apple ID（功能有限）
- **付费账号**：$99/年，功能完整（推荐）

### 2. 设备要求
- iPhone（iOS 17.0+）
- Apple Watch（watchOS 10.0+，与 iPhone 配对）
- USB 数据线（用于连接 iPhone）
- Mac（用于 Xcode）

### 3. 软件要求
- Xcode 15.0+
- 最新版本的 macOS

---

## 🚀 步骤 1：配置开发者账号

### 在 Xcode 中登录 Apple ID

1. 打开 Xcode
2. 菜单栏：**Xcode → Settings** (或 **Preferences**)
3. 选择 **Accounts** 标签
4. 点击左下角 **+** 按钮
5. 选择 **Apple ID**
6. 输入你的 Apple ID 和密码
7. 点击 **Sign In**

### 验证账号状态
- 如果看到 "Personal Team"，说明已成功登录
- 如果是付费开发者，会显示 "Apple Developer Program"

---

## 🔧 步骤 2：配置项目签名

### 2.1 配置 iOS Target

1. 在 Xcode 中打开项目
2. 选择项目文件（左侧导航栏最顶部）
3. 选择 **Silent Gym** target
4. 选择 **Signing & Capabilities** 标签

#### 配置签名：
- ✅ **Automatically manage signing**（勾选）
- **Team**：选择你的 Apple ID 或开发者团队
- **Bundle Identifier**：确保是唯一的（例如：`com.yourname.slientgym`）

#### 配置 Capabilities：
确保以下 Capabilities 已添加：
- ✅ **HealthKit**
- ✅ **WatchConnectivity**

### 2.2 配置 watchOS Target（如果存在）

1. 选择 **Silent Gym Watch App** target
2. 选择 **Signing & Capabilities** 标签

#### 配置签名：
- ✅ **Automatically manage signing**（勾选）
- **Team**：选择与 iOS target 相同的团队
- **Bundle Identifier**：应该是 `com.yourname.slientgym.watchkitapp`

#### 配置 Capabilities：
- ✅ **HealthKit**

---

## 📱 步骤 3：连接 iPhone

### 3.1 物理连接

1. 使用 USB 数据线连接 iPhone 到 Mac
2. 在 iPhone 上：**设置 → 通用 → VPN与设备管理**
3. 信任你的 Mac（如果提示）

### 3.2 在 Xcode 中选择设备

1. 在 Xcode 顶部工具栏，点击设备选择器
2. 选择你的 iPhone（应该会显示设备名称）
3. 如果设备显示为灰色，可能需要：
   - 解锁 iPhone
   - 点击 "Trust This Computer"
   - 在 iPhone 上输入密码

---

## ⌚ 步骤 4：配置 Apple Watch

### 4.1 确保 Watch 已配对

1. 在 iPhone 上打开 **Watch** 应用
2. 确认 Apple Watch 已配对并显示在列表中
3. 确保 Watch 已解锁

### 4.2 在 Xcode 中选择 Watch

1. 在 Xcode 设备选择器中，展开你的 iPhone
2. 应该能看到配对的 Apple Watch
3. 如果看不到，可能需要：
   - 重启 Watch
   - 重新配对 Watch

---

## 🏗️ 步骤 5：构建和运行

### 5.1 构建 iOS App

1. 在 Xcode 顶部，确保选择了 **Silent Gym** scheme
2. 选择你的 iPhone 作为目标设备
3. 点击 **▶️ Run** 按钮（或按 `Cmd + R`）

#### 首次运行可能遇到的问题：

**问题 1：签名错误**
```
No signing certificate found
```
**解决**：
- Xcode 会自动创建证书，等待几秒钟
- 如果失败，检查 Team 设置是否正确

**问题 2：设备未信任**
```
Untrusted Developer
```
**解决**：
- 在 iPhone 上：**设置 → 通用 → VPN与设备管理**
- 找到你的开发者证书
- 点击 **信任**

**问题 3：Provisioning Profile 错误**
```
No provisioning profile found
```
**解决**：
- 确保 "Automatically manage signing" 已勾选
- 尝试 Clean Build Folder（`Cmd + Shift + K`）
- 重新构建

### 5.2 构建 watchOS App（如果已配置）

1. 在 Xcode 顶部，选择 **Silent Gym Watch App** scheme
2. 选择配对的 Apple Watch 作为目标设备
3. 点击 **▶️ Run** 按钮

---

## ⚙️ 步骤 6：配置 Info.plist 权限

### 6.1 iOS Info.plist

确保以下权限描述已添加：

```xml
<key>NSHealthShareUsageDescription</key>
<string>我们需要访问您的健康数据来记录训练和导入跑步记录。</string>

<key>NSHealthUpdateUsageDescription</key>
<string>我们需要写入健康数据来记录您的训练。</string>

<key>NSCalendarsUsageDescription</key>
<string>我们需要访问您的日历来添加训练记录。</string>
```

### 6.2 watchOS Info.plist

```xml
<key>NSHealthShareUsageDescription</key>
<string>我们需要访问您的健康数据来记录训练。</string>

<key>NSHealthUpdateUsageDescription</key>
<string>我们需要写入健康数据来记录您的训练。</string>
```

---

## 🔍 步骤 7：测试应用

### 7.1 首次启动

1. 应用安装后，首次打开会请求权限：
   - ✅ **HealthKit** 权限（读取和写入）
   - ✅ **Calendar** 权限（添加事件）

2. 点击 **允许** 授予权限

### 7.2 测试功能

#### iOS App：
- ✅ 查看示例数据（Day A/B/C）
- ✅ 开始训练
- ✅ 记录数据
- ✅ 查看历史
- ✅ 查看进度

#### Watch App（如果已配置）：
- ✅ 启动 workout
- ✅ 查看心率
- ✅ 查看时间

---

## 🐛 常见问题排查

### 问题 1：应用无法安装

**可能原因**：
- 设备存储空间不足
- 签名证书问题
- Bundle ID 冲突

**解决**：
1. 检查设备存储空间
2. 清理旧的构建（`Product → Clean Build Folder`）
3. 检查 Bundle ID 是否唯一

### 问题 2：Watch App 无法安装

**可能原因**：
- Watch 未配对
- Watch 存储空间不足
- 签名问题

**解决**：
1. 确认 Watch 已配对
2. 检查 Watch 存储空间
3. 确保 watchOS target 签名正确

### 问题 3：HealthKit 权限被拒绝

**解决**：
1. 在 iPhone 上：**设置 → 健康 → 数据访问权限与设备**
2. 找到你的应用
3. 开启所有权限

### 问题 4：WatchConnectivity 不工作

**可能原因**：
- Watch App 未安装
- Watch 未配对
- 权限问题

**解决**：
1. 确保 Watch App 已安装
2. 确保 Watch 已配对并连接
3. 重启两个应用

---

## 📝 注意事项

### 免费账号限制：
- ✅ 可以安装到自己的设备
- ✅ 可以测试所有功能
- ❌ 应用 7 天后会过期（需要重新安装）
- ❌ 无法发布到 App Store

### 付费账号优势：
- ✅ 应用不会过期
- ✅ 可以发布到 App Store
- ✅ 可以使用 TestFlight
- ✅ 可以使用更多功能

---

## 🎯 快速检查清单

在运行前，确保：

- [ ] Apple ID 已登录到 Xcode
- [ ] iOS target 签名已配置
- [ ] watchOS target 签名已配置（如果存在）
- [ ] iPhone 已连接并信任
- [ ] Apple Watch 已配对
- [ ] Info.plist 权限已添加
- [ ] Capabilities 已启用
- [ ] Bundle ID 是唯一的

---

## 🚀 开始测试！

现在你可以：
1. 在 iPhone 上测试所有功能
2. 在 Apple Watch 上测试 workout（如果已配置）
3. 测试 HealthKit 集成
4. 测试 Calendar 集成
5. 测试 NRC 导入

**祝测试顺利！** 🎉

---

## 📞 需要帮助？

如果遇到问题：
1. 检查 Xcode Console 中的错误信息
2. 查看设备日志（Window → Devices and Simulators）
3. 确保所有权限已授予
4. 尝试 Clean Build 并重新安装


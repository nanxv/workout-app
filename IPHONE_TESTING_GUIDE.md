# iPhone 真机测试指南

## 准备工作

### 1. 注册 Apple Developer 账号（免费）

有两种方式：

#### 方式 A：免费个人开发者账号（推荐）
- 无需付费，可以测试 7 天
- 7 天后需要重新安装
- 适合个人开发测试

#### 方式 B：付费开发者账号（$99/年）
- 可以长期使用
- 可以发布到 App Store
- 适合商业开发

### 2. 在 Xcode 中登录 Apple ID

1. 打开 Xcode
2. 点击菜单栏 **Xcode > Settings** (或 **Preferences**)
3. 切换到 **Accounts** 标签
4. 点击左下角的 **+** 按钮
5. 选择 **Apple ID**
6. 输入你的 Apple ID 和密码
7. 点击 **Sign In**

## 配置项目签名

### 1. 选择项目

1. 在 Xcode 中打开项目
2. 点击左侧项目导航器中的项目文件（最顶部的蓝色图标）
3. 选择 **Silent Gym** target（不是项目，是 target）

### 2. 配置 Signing & Capabilities

1. 切换到 **Signing & Capabilities** 标签
2. 勾选 **Automatically manage signing**
3. 在 **Team** 下拉菜单中选择你的 Apple ID（如果没有，点击 **Add Account...**）
4. Xcode 会自动生成 Provisioning Profile 和证书

### 3. 配置 Bundle Identifier

1. 在 **Signing & Capabilities** 中，找到 **Bundle Identifier**
2. 确保它是唯一的，例如：`ZC.POB.Silent-Gym`（如果冲突，可以改成 `com.yourname.Silent-Gym`）

## 连接 iPhone

### 1. 物理连接

1. 使用 USB 数据线将 iPhone 连接到 Mac
2. 在 iPhone 上，如果弹出"要信任此电脑吗？"，点击 **信任**
3. 输入 iPhone 的密码确认

### 2. 在 iPhone 上启用开发者模式（iOS 16+）

如果是 iOS 16 或更高版本：

1. 打开 iPhone **设置**
2. 进入 **隐私与安全性**
3. 找到 **开发者模式**（如果没有，说明还没安装过开发者应用）
4. 开启 **开发者模式**
5. 重启 iPhone
6. 重启后，会弹出确认对话框，点击 **打开**

## 在 Xcode 中运行

### 1. 选择设备

1. 在 Xcode 顶部工具栏，点击设备选择器（显示 "Any iOS Device" 或模拟器名称的地方）
2. 选择你的 iPhone（应该会显示设备名称，如 "iPhone 15 Pro"）

### 2. 运行应用

1. 点击 Xcode 左上角的 **运行按钮**（▶️）或按 **Cmd + R**
2. 如果是第一次安装，Xcode 会：
   - 编译项目
   - 安装应用到 iPhone
   - 启动应用

### 3. 信任开发者证书（首次安装）

如果是第一次安装，iPhone 上会显示：

1. 打开 iPhone **设置**
2. 进入 **通用 > VPN 与设备管理**（或 **设备管理**）
3. 找到你的开发者账号（显示为你的 Apple ID 邮箱）
4. 点击它
5. 点击 **信任 "你的 Apple ID"**
6. 再次确认 **信任**
7. 返回应用，现在应该可以正常打开了

## 常见问题

### Q: 设备选择器中看不到我的 iPhone

**解决方案：**
1. 检查 USB 连接是否正常
2. 尝试更换 USB 端口或数据线
3. 在 iPhone 上确认是否点击了"信任此电脑"
4. 重启 Xcode
5. 重启 iPhone

### Q: 提示 "No signing certificate found"

**解决方案：**
1. 确保在 Xcode Settings 中登录了 Apple ID
2. 在 Signing & Capabilities 中选择正确的 Team
3. 点击 **Automatically manage signing** 让 Xcode 自动处理

### Q: 提示 "Bundle identifier is already in use"

**解决方案：**
1. 修改 Bundle Identifier 为唯一值
2. 例如：`com.yourname.Silent-Gym` 或 `com.yourname.slientgym`

### Q: 应用安装后无法打开，显示"未受信任的企业级开发者"

**解决方案：**
1. 打开 iPhone **设置 > 通用 > VPN 与设备管理**
2. 找到你的开发者账号
3. 点击 **信任**

### Q: 应用运行后立即崩溃

**解决方案：**
1. 检查 Xcode Console 中的错误信息
2. 确保所有权限描述已添加到 Info.plist（HealthKit、Calendar）
3. 检查是否有编译错误或警告

### Q: 免费账号 7 天后应用无法打开

**解决方案：**
1. 这是正常现象，免费账号的应用只能使用 7 天
2. 重新在 Xcode 中运行应用即可（会重新签名）
3. 或者升级到付费开发者账号

## 无线调试（可选）

### 启用无线调试

1. 确保 iPhone 和 Mac 连接到同一个 Wi-Fi 网络
2. 在 Xcode 中，选择 **Window > Devices and Simulators**
3. 选择你的 iPhone
4. 勾选 **Connect via network**
5. 断开 USB 连接
6. 现在可以在设备选择器中选择 iPhone（无线）

## 查看日志和调试

### 1. 查看 Console 日志

1. 在 Xcode 底部打开 **Console** 面板
2. 运行应用时，所有 `print()` 输出都会显示在这里

### 2. 使用断点调试

1. 在代码行号左侧点击，设置断点（红色圆点）
2. 运行应用
3. 当代码执行到断点时，会暂停
4. 可以查看变量值、单步执行等

### 3. 查看设备日志

1. 在 Xcode 中选择 **Window > Devices and Simulators**
2. 选择你的 iPhone
3. 点击 **View Device Logs** 查看所有日志

## 测试清单

在真机上测试时，确保测试以下功能：

- [ ] 应用可以正常启动
- [ ] 可以创建和查看训练计划
- [ ] 可以开始训练并记录数据
- [ ] HealthKit 权限请求正常弹出
- [ ] Calendar 权限请求正常弹出
- [ ] 训练数据可以保存
- [ ] 历史记录可以查看
- [ ] 进度统计正常显示
- [ ] AI 教练功能正常

## 注意事项

1. **首次安装需要信任证书**：这是 iOS 的安全机制
2. **免费账号限制**：免费账号的应用只能使用 7 天，之后需要重新安装
3. **权限请求**：确保 Info.plist 中已添加所有必要的权限描述
4. **网络连接**：某些功能（如 OpenAI）可能需要网络连接
5. **设备兼容性**：确保 iPhone 运行 iOS 17.0 或更高版本

## 下一步

测试完成后，如果一切正常，可以考虑：
- 优化用户体验
- 添加更多功能
- 准备发布到 App Store（需要付费开发者账号）


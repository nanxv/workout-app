# iPhone 真机测试快速指南

## 第一步：在 Xcode 中登录 Apple ID

1. 打开 Xcode
2. 点击菜单栏 **Xcode > Settings**（或 **Preferences**）
3. 切换到 **Accounts** 标签
4. 点击左下角的 **+** 按钮
5. 选择 **Apple ID**
6. 输入你的 Apple ID 和密码
7. 点击 **Sign In**

> 💡 **提示**：使用免费 Apple ID 即可，无需付费开发者账号。免费账号的应用可以使用 7 天。

---

## 第二步：连接 iPhone

1. 使用 USB 数据线将 iPhone 连接到 Mac
2. 在 iPhone 上，如果弹出"要信任此电脑吗？"，点击 **信任**
3. 输入 iPhone 的密码确认

---

## 第三步：配置项目签名

1. 在 Xcode 中，点击左侧项目导航器中的项目文件（最顶部的蓝色图标）
2. 选择 **Silent Gym** target（不是项目，是 target）
3. 切换到 **Signing & Capabilities** 标签
4. 勾选 **Automatically manage signing**
5. 在 **Team** 下拉菜单中选择你的 Apple ID
6. 如果 Bundle Identifier 冲突，修改为唯一值（例如：`com.yourname.Silent-Gym`）

---

## 第四步：选择设备并运行

1. 在 Xcode 顶部工具栏，点击设备选择器（显示 "Any iOS Device" 或模拟器名称的地方）
2. 选择你的 iPhone（应该会显示设备名称，如 "iPhone 15 Pro"）
3. 点击 Xcode 左上角的 **运行按钮**（▶️）或按 **Cmd + R**
4. Xcode 会：
   - 编译项目
   - 安装应用到 iPhone
   - 启动应用

---

## 第五步：信任开发者证书（首次安装）

如果是第一次安装，iPhone 上会显示"未受信任的企业级开发者"：

1. 打开 iPhone **设置**
2. 进入 **通用 > VPN 与设备管理**（或 **设备管理**）
3. 找到你的开发者账号（显示为你的 Apple ID 邮箱）
4. 点击它
5. 点击 **信任 "你的 Apple ID"**
6. 再次确认 **信任**
7. 返回应用，现在应该可以正常打开了

---

## 第六步：授权权限

首次使用时，应用会请求权限：

### HealthKit 权限
- 点击 **允许** 或 **不允许**
- 建议选择 **允许**，以便完整测试功能

### Calendar 权限
- 点击 **允许** 或 **不允许**
- 建议选择 **允许**，以便测试日历功能

> ⚠️ **注意**：如果拒绝了权限，应用不会崩溃，但相关功能无法使用。

---

## 常见问题解决

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

### Q: 应用安装后无法打开

**解决方案：**
1. 打开 iPhone **设置 > 通用 > VPN 与设备管理**
2. 找到你的开发者账号
3. 点击 **信任**

### Q: 应用运行后立即崩溃

**解决方案：**
1. 检查 Xcode Console 中的错误信息
2. 确保所有权限描述已添加到 Info.plist（见下一步）
3. 检查是否有编译错误或警告

---

## 重要：添加权限描述

在 Xcode 中，选择 **Silent Gym** target，切换到 **Info** 标签，添加以下权限描述：

| Key | Value |
|-----|-------|
| `Privacy - Health Share Usage Description` | `用于读取并展示你的跑步与训练数据（例如 Nike Run Club 同步到"健康"的记录）。` |
| `Privacy - Health Update Usage Description` | `用于将本应用记录的力量训练写入"健康"。` |
| `Privacy - Calendars Usage Description` | `用于把你的训练记录添加到系统日历。` |

> 📝 详细内容见 `docs/INFO_PLIST_SNIPPETS.md`

---

## 测试清单

安装成功后，测试以下功能：

- [ ] 应用可以正常启动
- [ ] 可以创建和查看训练计划（Day A/B/C）
- [ ] 可以开始训练并记录数据
- [ ] HealthKit 权限请求正常弹出
- [ ] Calendar 权限请求正常弹出
- [ ] 训练数据可以保存
- [ ] 历史记录可以查看
- [ ] 进度统计正常显示
- [ ] AI 教练功能正常

---

## 免费账号限制

使用免费 Apple ID 签名的应用：
- ✅ 可以使用 7 天
- ✅ 7 天后需要重新在 Xcode 中运行（会重新签名）
- ✅ 适合个人开发测试
- ❌ 不能发布到 App Store（需要付费开发者账号）

---

## 下一步

测试完成后：
1. 如果发现问题，查看 Xcode Console 日志
2. 检查权限是否正确授权
3. 验证所有功能是否正常

详细测试指南请参考：`IPHONE_TESTING_GUIDE.md`


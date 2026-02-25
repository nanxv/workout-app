# 应用名称更新指南：改为"简练"

## 在 Xcode 中更新应用显示名称

### 方法 1：在 Info 标签中添加（推荐）

1. **打开 Xcode 项目**
2. **选择项目文件**（最顶部的蓝色图标）
3. **选择 "Slient Gym" target**（不是项目）
4. **切换到 "Info" 标签**
5. **在 "Custom iOS Target Properties" 部分，点击 "+" 按钮添加：**

| Key | Type | Value |
|-----|------|-------|
| **Bundle display name** | String | `简练` |

### 方法 2：在 Build Settings 中添加

1. **选择 "Slient Gym" target**
2. **切换到 "Build Settings" 标签**
3. **在搜索框中输入 `INFOPLIST_KEY`**
4. **点击 "+" 按钮添加：**

- **INFOPLIST_KEY_CFBundleDisplayName** = `简练`

## 验证

1. **清理构建**：`Product > Clean Build Folder` (Shift+Cmd+K)
2. **重新构建**：`Product > Build` (Cmd+B)
3. **运行应用**：在设备或模拟器上，应用图标下方应该显示"简练"

## 注意事项

- **Bundle Identifier** 保持不变：`ZC.POB.Slient-Gym`（不需要改）
- **项目名称**（Slient Gym）可以保持不变，只改显示名称
- **代码中的引用**（如 `Slient_GymApp`）不需要改，只影响用户看到的名称

## 图标

您提供的图标（哑铃 + 勾选标记）非常适合"简练"这个名称，体现了：
- **简洁高效**：简练的设计理念
- **完成目标**：勾选标记代表完成训练
- **力量训练**：哑铃代表健身主题





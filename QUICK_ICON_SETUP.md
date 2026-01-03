# 快速设置应用图标

## 步骤 1：准备图标文件

您需要准备一个 **1024×1024** 像素的图标文件（PNG 格式）。

## 步骤 2：生成所有尺寸（推荐方法）

### 使用在线工具（最简单）

1. 访问 [AppIcon.co](https://www.appicon.co/)
2. 点击 "Upload Image"
3. 上传您的 1024×1024 图标
4. 选择 "iOS" 平台
5. 点击 "Generate"
6. 下载生成的 ZIP 文件
7. 解压 ZIP 文件

### 或使用 macOS 应用

1. 下载 [Image2icon](https://www.img2icns.app/)（免费）
2. 打开应用
3. 拖入您的 1024×1024 图标
4. 选择 "iOS App Icon"
5. 点击 "Export"

## 步骤 3：在 Xcode 中添加图标

### 方法 A：拖拽到 Asset Catalog（推荐）

1. **打开 Xcode**
2. **在项目导航器中，找到并展开 `Slient Gym/Assets.xcassets`**
3. **点击 `AppIcon`**
4. **将生成的图标文件拖拽到对应的尺寸槽位：**

   - **App Store (1024×1024)** → 拖入 `AppIcon-1024.png`
   - **iPhone 60pt (120×120)** → 拖入 `AppIcon-60@2x.png`
   - **iPhone 60pt (180×180)** → 拖入 `AppIcon-60@3x.png`
   - 其他尺寸（可选，但推荐）

5. **Xcode 会自动识别并填充**

### 方法 B：手动复制文件

1. **找到图标文件目录**：
   ```
   Slient Gym/Assets.xcassets/AppIcon.appiconset/
   ```

2. **复制所有 PNG 文件到此目录**

3. **在 Xcode 中刷新**：右键点击 `AppIcon` → "Show in Finder"

## 步骤 4：验证

1. **清理构建**：`Product > Clean Build Folder` (Shift+Cmd+K)
2. **重新构建**：`Product > Build` (Cmd+B)
3. **运行应用**：在设备或模拟器上查看图标

## 最小要求

如果时间紧迫，至少需要提供：

- ✅ **1024×1024** - App Store
- ✅ **180×180** - iPhone App Icon @3x
- ✅ **120×120** - iPhone App Icon @2x

这三个尺寸可以确保应用在 iPhone 上正常显示。

## 图标设计提示

根据您的图标（哑铃 + 勾选标记）：

- ✅ 使用纯色背景（黑色或白色）
- ✅ 保持简洁，符合"简练"理念
- ✅ 确保在小尺寸下也清晰可见
- ✅ 避免在图标中添加文字

## 故障排除

**图标不显示？**
- 检查文件是否在 `AppIcon.appiconset` 目录中
- 检查文件名是否正确
- 清理构建缓存后重新构建

**图标显示模糊？**
- 确保使用正确尺寸（不要缩放）
- 使用 PNG 格式，不要用 JPEG


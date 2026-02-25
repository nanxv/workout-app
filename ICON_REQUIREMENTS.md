# 应用图标要求清单

## 必需尺寸（最小集）

为了应用能够正常显示，至少需要以下尺寸：

1. **1024×1024** - App Store 图标（必需）
2. **180×180** - iPhone App Icon @3x（必需）
3. **120×120** - iPhone App Icon @2x（必需）

## 完整尺寸列表（推荐）

为了在所有场景下都有最佳显示效果，建议提供以下所有尺寸：

### iPhone 图标

| 尺寸 | 文件名 | 用途 |
|------|--------|------|
| 40×40 | `AppIcon-20@2x.png` | Notification @2x |
| 60×60 | `AppIcon-20@3x.png` | Notification @3x |
| 58×58 | `AppIcon-29@2x.png` | Settings @2x |
| 87×87 | `AppIcon-29@3x.png` | Settings @3x |
| 80×80 | `AppIcon-40@2x.png` | Spotlight @2x |
| 120×120 | `AppIcon-40@3x.png` | Spotlight @3x |
| 120×120 | `AppIcon-60@2x.png` | App Icon @2x |
| 180×180 | `AppIcon-60@3x.png` | App Icon @3x |
| 1024×1024 | `AppIcon-1024.png` | App Store |

## 快速生成所有尺寸

### 方法 1：使用在线工具（推荐）

1. 访问 [AppIcon.co](https://www.appicon.co/)
2. 上传您的 1024×1024 图标
3. 选择 iOS 平台
4. 下载生成的图标包
5. 解压后，将所有 PNG 文件复制到 `Slient Gym/Assets.xcassets/AppIcon.appiconset/` 目录

### 方法 2：使用 Image2icon（macOS App）

1. 下载 [Image2icon](https://www.img2icns.app/)（免费）
2. 打开应用
3. 拖入您的 1024×1024 图标
4. 选择 "iOS App Icon"
5. 导出到 `Slient Gym/Assets.xcassets/AppIcon.appiconset/` 目录

## 在 Xcode 中设置

1. **打开 Xcode**
2. **在项目导航器中，找到 `Slient Gym/Assets.xcassets`**
3. **展开并点击 `AppIcon`**
4. **将图标文件拖拽到对应的尺寸槽位**

   - 如果使用自动生成工具，所有尺寸会自动填充
   - 如果手动添加，至少需要填充 1024×1024、180×180、120×120

5. **验证**：确保所有必需尺寸都已填充（显示为蓝色，不是灰色）

## 图标设计规范

根据您的图标（哑铃 + 勾选标记），建议：

1. **背景**：使用纯色背景（黑色或白色），避免透明
2. **设计**：保持简洁，符合"简练"理念
3. **细节**：确保在小尺寸（60×60）下也清晰可见
4. **对比度**：确保图标与背景有足够对比度
5. **无文字**：图标中不要包含文字或数字

## 验证步骤

1. **清理构建**：`Product > Clean Build Folder` (Shift+Cmd+K)
2. **重新构建**：`Product > Build` (Cmd+B)
3. **运行应用**：在设备上查看图标
4. **检查**：
   - 主屏幕图标显示正常
   - 设置中图标显示正常
   - Spotlight 搜索中图标显示正常

## 故障排除

### 图标不显示或显示默认图标

- 检查文件名是否正确
- 检查 `Contents.json` 中的文件名引用是否正确
- 确保图标文件在 `AppIcon.appiconset` 目录中
- 清理构建缓存后重新构建

### 图标显示模糊

- 确保使用了正确尺寸的图标（不要缩放）
- 使用 PNG 格式，避免 JPEG
- 确保图标是正方形，没有圆角（iOS 会自动添加）





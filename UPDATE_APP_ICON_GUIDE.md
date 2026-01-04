# 更新应用图标指南

## 图标要求

iOS 应用图标需要提供多种尺寸，以适配不同的设备和用途：

### iPhone 图标尺寸（必需）

| 尺寸 | 用途 | 文件名建议 |
|------|------|-----------|
| 60×60 @2x (120×120) | iPhone App Icon | `AppIcon-60@2x.png` |
| 60×60 @3x (180×180) | iPhone App Icon | `AppIcon-60@3x.png` |
| 1024×1024 | App Store | `AppIcon-1024.png` |

### 完整尺寸列表（推荐）

| 尺寸 | 用途 |
|------|------|
| 20×20 @2x (40×40) | Notification |
| 20×20 @3x (60×60) | Notification |
| 29×29 @2x (58×58) | Settings |
| 29×29 @3x (87×87) | Settings |
| 40×40 @2x (80×80) | Spotlight |
| 40×40 @3x (120×120) | Spotlight |
| 60×60 @2x (120×120) | App Icon |
| 60×60 @3x (180×180) | App Icon |
| 1024×1024 | App Store |

## 在 Xcode 中更新图标

### 方法 1：使用 Asset Catalog（推荐）

1. **打开 Xcode 项目**
2. **在项目导航器中，找到 `Slient Gym/Assets.xcassets`**
3. **展开 `Assets.xcassets`，点击 `AppIcon`**
4. **将您的图标文件拖拽到对应的尺寸槽位中**

   - **App Store (1024×1024)**：拖拽 1024×1024 的图标
   - **iPhone 60pt (120×120)**：拖拽 120×120 的图标
   - **iPhone 60pt (180×180)**：拖拽 180×180 的图标

5. **Xcode 会自动识别并填充其他尺寸（如果提供了）**

### 方法 2：替换图标文件

1. **准备图标文件**：
   - 至少需要：1024×1024、180×180、120×120
   - 格式：PNG（推荐）或 JPEG
   - 背景：可以是透明或纯色

2. **替换文件**：
   - 找到 `Slient Gym/Assets.xcassets/AppIcon.appiconset/` 目录
   - 将您的图标文件复制到此目录
   - 更新 `Contents.json` 中的文件名引用

3. **更新 Contents.json**：
   ```json
   {
     "images": [
       {
         "filename": "AppIcon-1024.png",
         "idiom": "universal",
         "platform": "ios",
         "size": "1024x1024"
       },
       {
         "filename": "AppIcon-60@2x.png",
         "idiom": "iphone",
         "scale": "2x",
         "size": "60x60"
       },
       {
         "filename": "AppIcon-60@3x.png",
         "idiom": "iphone",
         "scale": "3x",
         "size": "60x60"
       }
     ],
     "info": {
       "author": "xcode",
       "version": 1
     }
   }
   ```

## 图标设计建议

根据您提供的图标（哑铃 + 勾选标记），建议：

1. **保持简洁**：符合"简练"的设计理念
2. **高对比度**：确保在小尺寸下也清晰可见
3. **无文字**：图标中不要包含文字（系统会自动显示应用名称）
4. **圆角处理**：iOS 会自动添加圆角，设计时不需要预先添加
5. **避免透明背景**：使用纯色背景（如黑色或白色）

## 验证图标

1. **清理构建**：`Product > Clean Build Folder` (Shift+Cmd+K)
2. **重新构建**：`Product > Build` (Cmd+B)
3. **运行应用**：在设备或模拟器上查看图标
4. **检查所有尺寸**：确保在不同设备上图标显示正常

## 工具推荐

如果需要生成所有尺寸的图标，可以使用：

- **在线工具**：
  - [AppIcon.co](https://www.appicon.co/)
  - [IconKitchen](https://icon.kitchen/)
  
- **macOS 应用**：
  - **Icon Generator**（App Store）
  - **Image2icon**（免费）

只需提供 1024×1024 的图标，这些工具会自动生成所有需要的尺寸。

## 注意事项

- **图标文件大小**：每个图标文件不应超过 500KB
- **格式**：推荐使用 PNG，避免使用 JPEG（可能有压缩损失）
- **设计规范**：遵循 [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- **测试**：在不同设备上测试图标显示效果



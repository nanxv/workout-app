# Cursor 执行指南

## 快速开始

把 `TASKS_M1_CHECKLIST.md` 按顺序逐项打勾；Info.plist 按 `docs/INFO_PLIST_SNIPPETS.md` 添加；CI 用 `.github/workflows/ci.yml`；权限引导文案用 `docs/PERMISSION_GUIDE.md`。完成后按 P0/P1/P2 的"验收标准"在真机逐个过一遍即可。

## 执行顺序

### 第一步：Xcode 配置（P0）
1. 打开 Xcode 项目
2. 按照 `TASKS_M1_CHECKLIST.md` 的 P0 部分逐项完成：
   - 重命名项目（Silent → Silent）
   - 配置 Capabilities
   - 添加 Info.plist 权限描述（参考 `docs/INFO_PLIST_SNIPPETS.md`）
   - 检查 Target Membership

### 第二步：代码验证（P0）
1. 确保所有代码已实现（已完成）
2. 验证 RestTimer 时间戳校正
3. 验证 Watch 启动兜底机制
4. 验证权限拒绝不崩

### 第三步：真机测试（P0 验收）
1. iPhone 点"开始训练"→ Watch 立刻进入 workout
2. iPhone 点"结束训练"→ Health 出现"力量训练"
3. 切后台 30s 返回，倒计时准确扣 30s

### 第四步：P1 功能验证
1. History/Progress 显示同步状态
2. 日历事件保存成功
3. NRC 导入功能正常

### 第五步：P2 完善
1. 训练页状态点显示
2. CI 构建成功
3. 单元测试通过

## 参考文档

- **任务清单**：`TASKS_M1_CHECKLIST.md`
- **Info.plist 模板**：`docs/INFO_PLIST_SNIPPETS.md`
- **权限引导文案**：`docs/PERMISSION_GUIDE.md`
- **Watch 链路说明**：`docs/WATCH_LINK_NOTES.md`
- **CI 配置**：`.github/workflows/ci.yml`

## 注意事项

1. **命名**：完成重命名后，需要更新 CI 配置中的项目名称
2. **Capabilities**：必须在 Xcode 中手动配置，无法通过代码完成
3. **真机测试**：某些功能（如 Watch 连接）只能在真机上测试
4. **权限**：首次测试时需要在设置中手动授权


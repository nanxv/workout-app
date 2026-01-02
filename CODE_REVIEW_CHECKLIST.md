# 代码审查清单 - ChatGPT 审查意见

## 当前状态分析

### ✅ 已完成
- [x] 基础训练记录功能
- [x] SessionCoordinator 逐组记录
- [x] Watch 集成框架代码
- [x] Calendar 集成
- [x] NRC 导入框架
- [x] History 和 Progress 视图

### 🔄 需要改进
- [ ] RestTimerManager 时间戳校正（前后台切换）
- [ ] Watch 启动失败时的 WCSession 兜底
- [ ] 权限拒绝时的引导页面
- [ ] History 状态显示和重试功能
- [ ] 训练页状态点显示

### 📋 待配置（Xcode）
- [ ] 命名修正（Slient → Silent）
- [ ] Capabilities 配置
- [ ] Info.plist 权限描述
- [ ] Target Membership 配置

## 优先级

### P0 - 核心功能稳定性
1. RestTimerManager 时间戳校正
2. Watch 启动兜底机制
3. 权限拒绝处理

### P1 - 用户体验
4. 训练结束日历弹窗优化
5. History 状态显示
6. NRC 导入引导

### P2 - 工程质量
7. 状态点显示
8. 单元测试
9. CI 配置


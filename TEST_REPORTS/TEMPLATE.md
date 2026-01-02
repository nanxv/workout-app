# Silent Gym 测试报告（YYYY-MM-DD）

## 环境
- iPhone: iOS 18.1 / 型号
- Watch: watchOS 11.0 / 型号
- App Commit: <sha>
- 权限组合: Health(读/写)✅❌, Calendar✅❌, NRC→Health✅❌

## 结果摘要
- 通过: X / 失败: Y / 阻塞: Z
- P0 通过率: 100% / P1 通过率: %

## 关键用例结论（摘录）
- TC-B01: Pass（截图）
- TC-B02: Pass（健康 App 截图）
- TC-A02: Pass（后台 30s 校正）

## 失败与问题列表
- [#123] TC-D01 偶发失败：说明、日志、截图、复现概率
- [#124] …

## 建议 & 后续动作
- 建议对 RestTimer 增加 scenePhase 进入后台打点
- NRC 导入的时间窗口调大到 120 天（可配置）

## 附件
- 截图/录屏链接
- 控制台日志片段


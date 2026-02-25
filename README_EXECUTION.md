# 执行指南 - 给 Cursor

## 一句话总结

把 `TASKS_M1_CHECKLIST.md` 按顺序逐项打勾；Info.plist 按 `docs/INFO_PLIST_SNIPPETS.md` 添加；CI 用 `.github/workflows/ci.yml`；权限引导文案用 `docs/PERMISSION_GUIDE.md`。完成后按 P0/P1/P2 的"验收标准"在真机逐个过一遍即可。

## 文件结构

```
Silent Gym/
├── TASKS_M1_CHECKLIST.md          # 主任务清单（P0/P1/P2）
├── docs/
│   ├── INFO_PLIST_SNIPPETS.md     # Info.plist 内容模板
│   ├── PERMISSION_GUIDE.md        # 权限引导文案
│   ├── WATCH_LINK_NOTES.md        # Watch 链路技术说明
│   └── CURSOR_EXECUTION_GUIDE.md  # 详细执行指南
└── .github/workflows/
    └── ci.yml                      # CI 配置
```

## 快速开始

1. **阅读** `TASKS_M1_CHECKLIST.md` 了解所有任务
2. **参考** `docs/CURSOR_EXECUTION_GUIDE.md` 按步骤执行
3. **使用** `docs/INFO_PLIST_SNIPPETS.md` 添加权限描述
4. **参考** `docs/PERMISSION_GUIDE.md` 实现权限引导
5. **验证** 按照验收标准在真机测试

## 关键文件说明

- **TASKS_M1_CHECKLIST.md**：核心任务清单，按 P0/P1/P2 优先级组织
- **docs/INFO_PLIST_SNIPPETS.md**：可直接复制到 Xcode Info 标签的权限描述
- **docs/PERMISSION_GUIDE.md**：显示给用户的权限引导文案
- **docs/WATCH_LINK_NOTES.md**：iPhone→Watch 链路的技术实现要点
- **.github/workflows/ci.yml**：GitHub Actions CI 配置

## 注意事项

1. P0 任务必须在真机上验证
2. 某些配置（如 Capabilities）只能在 Xcode 中完成
3. 完成重命名后，需要更新 CI 配置中的项目名称
4. 所有代码层面的改进已完成，只需完成 Xcode 配置


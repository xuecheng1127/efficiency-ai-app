# 数据备份与恢复模块（P0 基础）

## ZIP 结构
```
backup_YYYYMMDD_HHmmss.zip
├── manifest.json      # 版本号 / 导出时间 / schema 版本
├── tasks.json         # 各模块数据 JSON
├── diary.json
├── workbench.json
├── ...
└── media/             # 图片/视频（保持相对路径）
```

## 关键约束
- 导出/导入大数据量用 `Isolate.run` / `compute`，避免阻塞 UI 与 OOM
- 恢复流程：选 ZIP → 校验 manifest 版本 → 覆盖/合并 → 导入媒体 + 重建路径映射 → 重启
- 版本迁移：manifest 记录 schema 版本，导入旧版本执行增量迁移
- 可选 AES 加密（`cryptography` 包）

## TODO
- [ ] 导出打包（Isolate）
- [ ] 恢复 + 版本校验 + 迁移
- [ ] 媒体路径重建

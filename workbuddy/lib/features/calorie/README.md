# 热量管理模块（工具箱插件 + 共享数据源）

被任务模块、工具箱热量插件、工作台共同读写，作为**独立 Domain/Data 模块**，避免数据重复存储。

## BMR（Mifflin-St Jeor 公式）
- 男性：`10×体重 + 6.25×身高 - 5×年龄 + 5`
- 女性：`10×体重 + 6.25×身高 - 5×年龄 - 161`

## 当日总消耗
`BMR × 日常活动系数 + 健身任务同步消耗 + 手动运动 + 步数换算`

## 步数
走 Health Connect（见 `core/platform/health_connect_channel.dart`），每小时 WorkManager 同步。

## TODO
- [ ] CalorieRecord 表（date/type/source/amount）
- [ ] BMR 计算（纯 Dart，可单测）
- [ ] 迷你热量进度环（fl_chart）
- [ ] 步数同步接入

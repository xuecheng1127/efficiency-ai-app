# 架构决策记录（ADR）

> 本文件固化了《Flutter 效率应用 V1.0》在技术评审后对 6 个关键风险作出的最终决策。
> 每条决策包含：背景 → 决策 → 理由 → 后果。这些是项目后续开发的「约束条款」，不得随意推翻。

---

## ADR-001 · 本地数据库：Isar → Drift (SQLite)

- **状态**：已采纳
- **背景**：原始需求要求使用 Isar。但核实发现 Isar 原作者已弃坑、官方仓库停滞在 3.1.0、Isar 4 仍是 dev 且无法打开 v3 库、社区 fork `isar_community` 仅承诺修 bug。
- **决策**：**改用 Drift (SQLite)**。
- **理由**：Drift 活跃维护（当前 2.35.x）、基于最稳定的 SQLite、类型安全代码生成、原生 reactive stream（`watch()`）、迁移工具成熟；本项目的任务/日记/生日/热量/采购数据本质是关系型，SQLite 更契合。
- **后果**：
  - 原需求中"动态 JSON 结构"通过表的 `TEXT` 字段存 JSON 字符串实现（如工作台 `configJson`、日记 `contentJson`），读取后 `jsonDecode`，能力不降级。
  - 所有数据访问必须经 **Repository 接口**，把 Drift 实现隔离在 Data 层，未来可平滑替换。
  - 大数据量导入/导出/批量删除/复杂统计（热量汇总）必须用 `Isolate.run` / `compute`，避免阻塞 UI（沿用原需求对 Isar 的性能要求）。

## ADR-002 · 状态管理：Riverpod 3.x（手写 Provider）

- **状态**：已采纳
- **背景**：原需求要求 Riverpod 2.x。但 Riverpod 3.0 已于 2025-09 稳定，2.x 进入维护，新项目默认 3.x。
- **决策**：**使用 Riverpod 3.x**（flutter_riverpod ^3.4），统一 `AsyncValue` 处理异步状态。
- **理由**：3.x 是当前生态默认，`Ref` 类型统一、自动重试、`ref.mounted` 等特性更利于本项目。
- **后果**：
  - 本项目**手写 Provider**（`NotifierProvider` / `StreamProvider`），不引入 `riverpod_generator` 代码生成，减少 build_runner 依赖点与版本耦合。
  - `freezed + json_serializable` 仅用于**动态 JSON 实体**（闹钟配置、日记排版区块、工作台配置等），表数据直接用 Drift 生成的不可变 row，避免重复定义与映射样板。

## ADR-003 · 精确闹钟：三档降级方案（无法保证 100% 准时）

- **状态**：已采纳
- **背景**：原需求要求 `setExactAndAllowWhileIdle` 保证准时。核实发现 Android 14+ 对 target 33+ 新装应用**默认拒绝** `SCHEDULE_EXACT_ALARM` 且无授权弹窗，非闹钟/日历类应用不能用 `USE_EXACT_ALARM`。
- **决策**：**"准时"作为尽力目标，实现三档降级**：
  | 档位 | 触发条件 | 实现 |
  |---|---|---|
  | A 精确档 | `canScheduleExactAlarms() == true` | `setExactAndAllowWhileIdle` |
  | B 近似档 | 精确权限被拒 | `setAndAllowWhileIdle` + WorkManager 周期扫描兜底 |
  | C 应用内档 | 应用在前台 | 应用内定时器 + 通知 |
- **理由**：Android 14+ 的原生层面已无法保证准时，只能尽力逼近。
- **后果**：
  - 首次绑定闹钟时场景化引导用户开启"闹钟和提醒"权限（跳转 `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`）。
  - 监听 `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`，权限恢复后自动重设。
  - **必须实现 `BOOT_COMPLETED` 接收器**：重启后闹钟全部丢失，开机时从数据库重建未来闹钟。
  - 全屏闹钟页需 `USE_FULL_SCREEN_INTENT`（Android 14+ 该权限对非通话类应用同样收紧，需一并申请并降级）。

## ADR-004 · 步数同步：走 Health Connect（Google Fit 已废弃）

- **状态**：已采纳
- **背景**：Google Fit API 2026 年底停服，`health` 插件 v11+ 已移除 Fit 支持。
- **决策**：Android 步数**统一走 Health Connect**，抽象 `StepDataSource` 接口。
- **理由**：Health Connect 是 Google 官方指定的移动端步数方案；`health` 插件已原生支持。
- **后果**：
  - `AndroidManifest.xml` 声明 Health Connect READ 权限；Android 9–13 需引导用户安装 Health Connect 应用。
  - 上架需提供隐私政策链接（健康数据属敏感权限，审核更严）。
  - "每小时同步一次"用 WorkManager 周期任务（最小间隔 15 分钟），不用前台服务，省电合规。

## ADR-005 · 日记排版引擎：V1 范围裁剪 + 独立 PoC

- **状态**：已采纳
- **背景**：图文混排 + 文字避让 + 中文标点避头尾 + 增量重排 + 行级缓存，工作量已接近迷你排版系统，无现成控件。
- **决策**：
  - **V1.0**：图片作为**独立块级元素**插入正文，文字在图片上下流式排布；视频仅"插入占位 + 点击全屏播放"。
  - **降级到 V1.1**：图片任意位置自由拖拽 + 文字实时避让、增量重排。
  - 模块3 单独立项，先做 2 周 PoC 验证排版引擎可行性。
- **理由**：避免 V1.0 因最难模块无限延期。
- **后果**：排版引擎设计为可扩展架构（区块模型 + 分段渲染），V1.1 升级不推倒重来。

## ADR-006 · 国产 ROM 后台保活：缓解而非对抗

- **状态**：已采纳
- **背景**：小米/华为/OPPO/vivo 可能因电池优化杀前台服务或延迟闹钟，无方案能 100% 对抗。
- **决策**：三层缓解——① 引导用户关闭电池优化/加白名单（保活设置向导）；② 计时**持久化**（记录 `startedAt`，恢复时 `now - startedAt` 重算，进程被杀不丢进度）；③ 前台服务通知栏常驻。
- **理由**：技术无法对抗 ROM 策略，只能缓解 + 保证数据不丢。
- **后果**：计时状态以持久化时间为唯一真源，禁止依赖内存 Timer 累计。

## ADR-007 · 前台服务类型（`foregroundServiceType`）

- **状态**：**待定案**（保留编号，由 T17 在实测各类型时限后填写，字段含设备/系统版本/实测结果/来源链接）

## ADR-008 · 闹钟持久化：`scheduled_alarms` 表为唯一真源（T10）

- **状态**：已采纳
- **背景**：此前闹钟的全部调度参数只活在运行时（Intent extra / 内存）里。进程重建或设备重启后拿不到参数，**无法重建闹钟** —— 这是闹钟类应用的致命缺陷（`评审-闹钟模块-实现对照.md` 第一节）。
- **决策**：
  1. 新增 `scheduled_alarms` 表，落盘 11 个必持久化字段（`taskId/hour/minute/repeatRule/weekdays/scheduledDate/advanceMinutes/ringtone/volume/snoozeEnabled/snoozeMinutes`），并附 `tier` / `enabled` / `createdAt` / `updatedAt`。
  2. **表是闹钟参数的唯一真源**：写入时机为「调度闹钟时同步写入」；进程启动时完整读回；原生侧（含 T11 开机重建）一律从表读取，不再把参数塞进 `Intent`。
  3. 写入语义为**先删后插**（同一事务），配合 `task_id` 上的 UNIQUE 约束，结构性保证「一个任务至多一条闹钟记录」。
  4. `task_id` 外键指向 `task_templates(id)` 且 `ON DELETE CASCADE`；打开连接时 `PRAGMA foreign_keys = ON`。
  5. `tier` 列承载 A 精确 / B 近似 / C 应用内三档，供 T12 重排与 T18 界面展示。
  6. `enabled` 列使表能**独立**回答「有哪些闹钟要重建」，不依赖任何 `Intent`。
- **理由**：持久化是 T11 / T12 的前置，越晚做返工越大；把参数从 Intent 挪进表也一并消除了「重启后参数丢失」的根因。
- **后果**：
  - `schemaVersion` 2 → 3；V1.0 未发布、无真实用户数据，直接清库重建，不写未验证的迁移脚本。
  - 任务**硬删除**由外键级联清理；任务**归档**（`archivedAt` 软删）需在仓库层显式置 `enabled = 0` 或删除记录（T10 只提供能力，调用点由任务模块后续接入）。
  - 本工程未实现降级/重建逻辑（T11–T14、T19），T10 只交付**持久化能力**本身。

---

*以上决策自 2026-10-15 起生效，作为 V1.0 开发的强制约束。*

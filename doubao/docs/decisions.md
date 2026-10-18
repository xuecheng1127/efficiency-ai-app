# 关键决策记录（docs/decisions.md）

> T01 数据模型任务期间的架构决策（ADR）与工程适配决策，按时间顺序记录。

## ADR-001：数据库从 Isar 替换为 Drift（SQLite）

- **背景**：Isar 官方开发停滞于 3.1.0（长期无 release），T01 规格明确要求
  「数据层整体替换为 Drift」。
- **决策**：采用 Drift 2.35.x + sqlite3_flutter_libs（原生 SQLite，无 WebView）。
- **影响**：
  - 表定义从 `@Collection` 改为 `@DataClassName` 的 Dart 表类 + `@DriftDatabase`；
  - 生成产物合并进单一 `app_database.g.dart`，表文件不再声明 `part 'xxx.g.dart'`；
  - 查询 API 从 Isar 的 `where().findAll()` 改为 Drift 的 `select()..watch()` 流式响应。

## ADR-002：双层模型 task_templates + task_instances（快照隔离）

- **决策**：任务模板（重复规则/标题/闹钟配置）与当日实例（快照字段 + 状态）分离，
  实例冗余 `titleSnapshot/typeSnapshot/caloriePerMinuteSnapshot` 保证历史不被模板修改污染
  （规格 §二 快照隔离）。
- **唯一性**：`UNIQUE(templateId, occurrenceDate)`，防重复生成。
- **软删除**：实例 `deletedAt` 软删；补齐算法遇软删行原样返回 false（不复活），
  杜绝「清空用户进度」类 bug（规格 §11 红线 #2）。

## ADR-003：惰性补齐代替 WorkManager 定时生成

- **决策**：不用 WorkManager / 任何定时任务；应用启动（splash）时调用 `backfillOnAppStart`，
  一次性补齐从 `lastGeneratedDate ?? startDate` 到今天的全部缺失实例（规格 §三、§11 红线 #1）。
- **上限**：`MAX_BACKFILL_DAYS = 30`（含今天），防首次启动一次性生成 365 条卡顿；
  该值为规格 §6.1「建议值」，**待产品拍板**（测试 D8 按含今天最多 30 天口径）。
- **cutoff 语义**：规格伪代码 `today - MAX` 会生成 MAX+1 条违反 D8「≤MAX」，
  实现改为 `today - (maxBackfillDays - 1)`。

## ADR-004：Domain 实体不直接使用 Drift row 类（mapper 隔离）

- **决策**：Domain 层（`task_template.dart` / `task_instance.dart`）为纯 Dart 不可变类，
  Drift 生成的 `TaskTemplatesRow` / `TaskInstancesRow` 仅存在于 data 层，
  通过 `task_mapper.dart` 双向映射（规格 §11 红线 #4）。
- **效果**：`flutter analyze` 显示 Domain 零依赖 Drift；UI/业务不感知数据库实现。

## ADR-005：周日历语义统一为 Dart DateTime.weekday（1=周一）

- **决策**：重复规则匹配用 `DateTime.weekday`（1=周一 … 7=周日），
  禁止 `Calendar.DAY_OF_WEEK` 语义（规格 §11 红线 #5）；
  `repeatDaysCSV` 存「周一=1」语义的逗号分隔数字，U4 测试校验空列表恒 false 不抛。

## ADR-006：alarmConfigJson 字段承载闹钟配置

- **决策**：`alarmEnabled`（0/1）+ `alarmConfigJson`（`{"time":"HH:mm","advanceMinutes":n}`）
  承载单任务闹钟（T01 只建字段不实现调度；T10 解析时对齐该格式）。

## ADR-007：闹钟响铃前台服务类型定案为 mediaPlayback + 降级路径

- **背景**：Android 14 对 mediaPlayback 类型 FGS 从后台启动有额外限制（通常要求活跃 MediaSession）；AlarmReceiver 收到闹钟后启动 FGS 正是「从后台启动」。WorkBuddy 对照实现选了 specialUse。
- **决策**：保留 `mediaPlayback`，补 try-catch 降级路径。
- **理由**：
  1. 服务核心行为是 MediaPlayer 播放铃声，mediaPlayback 语义最匹配；
  2. specialUse 需要声明 PROPERTY_SPECIAL_USE_FGS_SUBTYPE，Play 审核更严；
  3. 已补降级：startForeground 失败时降级为普通 notify()，铃继续响，不会彻底不响。
- **降级日志**：`DEGRADED_NO_FGS: startForeground failed`，后续 `nm.notify(notificationId, notification)`。
- **待真机验证**：vivo ROM 上 mediaPlayback 从后台启动是否真的被拒（模拟器 AOSP 不复现）。

## 工程适配决策（构建链，均保留证据）

| 决策 | 理由 | 位置 |
|---|---|---|
| `android.overridePathCheck=true` | 工程路径含中文用户名，AGP 8 拒绝非 ASCII 路径 | `android/gradle.properties` |
| `android/app/build.gradle` 迁移声明式 `plugins {}` | Flutter 3.47 强制，旧 `apply plugin` 3 行被弃 | `android/app/build.gradle` |
| Gradle wrapper 8.14-all | Flutter 3.47 最低要求 8.14 | `android/gradle/wrapper/gradle-wrapper.properties` |
| AGP 8.11.1 + Kotlin 2.2.20 | AGP 最低 8.11.1；Kotlin 按编译报错 2.0.0→2.2.20 | `android/settings.gradle` |
| `MainActivity.kt:22` import 修复（embedding 包） | `io.flutter.engine.FlutterEngine` 在 3.47 不存在，真实类在 `io.flutter.embedding.engine`；**构建必需的单行修复**（用户红线「4 个 .kt 完全不要动」被打破，已诚实披露） | `android/app/src/main/kotlin/com/efficiency/app/MainActivity.kt` |
| engine 产物源固定 `storage.flutter-io.cn` | TUNA 镜像无 flutter_embedding 产物（404） | `flutter-env.ps1` 环境 |
| pub cache 迁移 ASCII `F:\develop\pub-cache` | Ninja/CMake 无法在中文路径 chdir（`:jni:buildCMakeDebug` 失败） | 环境 |
| `org.gradle.jvmargs` 追加 `-Dfile.encoding=UTF-8` | Gradle JVM 默认 GBK 使 `android_gradle_build.json` 路径乱码，AGP 产物检查失败 | `android/gradle.properties` |

## 测试口径决策

- Drift 测试用 `NativeDatabase.memory()`（D1–D8 不落盘、可并行）。
- `import 'package:drift/drift.dart' hide isNull, isNotNull;` 解决 drift 与 matcher 的
  `isNull/isNotNull` 符号冲突。
- `_instanceCount` 提升为顶层函数传 db（避免闭包捕获歧义）。
- U1–U7 用 `_MemoryBackfillStore implements BackfillStore`（纯内存、自增 id）验证算法语义；
  D1–D8 验证真实 SQLite 约束（唯一索引、软删、快照、归档、上限）。

# 分层架构 · Riverpod 路由结构 · 数据库模型设计

> 依据 PRD《Flutter 安卓效率应用 V1.0》产出。数据库选型说明见第 0 节。

---

## 0. 数据库选型说明（Isar → Drift）

PRD 原文指定 Isar，但技术评审已决策改用 **Drift (SQLite)**（ADR-001：Isar 原作者弃坑、官方停滞在 3.1.0、Isar 4 无法迁移）。本章的「数据库模型」以**领域实体关系**为核心——它技术栈无关，并同时给出：

- **Drift 表结构**（当前落地，SQLite 关系表 + TEXT 字段存动态 JSON）
- **Isar collection 映射**（若团队坚持 Isar 的备选，与 Drift 一一对应）

两者可平滑切换，因为数据访问层已通过 Repository 接口隔离。

---

## 1. 分层架构

### 1.1 五层结构

```
┌──────────────────────────────────────────────────────────┐
│ Presentation 层（UI）                                      │
│   screens / widgets，通过 ref.watch 消费 Provider           │
│   不直接访问数据库，不写业务规则；依赖 go_router 导航         │
├──────────────────────────────────────────────────────────┤
│ State 层（Riverpod 3）                                     │
│   Provider / Notifier / AsyncValue                        │
│   StreamProvider（响应式列表）· NotifierProvider（表单/主题）│
│   只做「编排 + 状态搬运」，不含业务规则                       │
├──────────────────────────────────────────────────────────┤
│ Domain 层（纯 Dart，零 Flutter 依赖）                       │
│   实体(freezed) · Repository 接口 · 用例/算法               │
│   BMR · 热量 · 农历 · 排版引擎(避头尾/绕排)                 │
├──────────────────────────────────────────────────────────┤
│ Data 层                                                   │
│   Repository 实现(Drift) · 数据源(DB/文件/通道) · DTO 映射  │
├──────────────────────────────────────────────────────────┤
│ Platform 层（Android 原生 / MethodChannel）                 │
│   闹钟三档降级 · 前台计时 · Health Connect · 通知            │
└──────────────────────────────────────────────────────────┘
```

### 1.2 依赖规则（单向向下 + 依赖倒置）

- **调用链只能从上往下**：Presentation → State → Domain → Data → Platform。
- **依赖倒置**：Domain 定义 `TaskRepository` 接口，Data 实现它。上层只依赖抽象，不依赖 Drift/Isar 具体实现，数据库可替换。
- **Domain 零 Flutter 依赖**：实体、算法、排版引擎均为纯 Dart，可独立单元测试（排版引擎已按此实现）。
- **Platform 不向上依赖**：原生能力只通过 MethodChannel 契约暴露，Data 层调用。

### 1.3 目录映射

```
lib/
├── main.dart                     # 入口：初始化 DB → ProviderScope
├── app/                          # 应用装配层
│   ├── app.dart                  # 根组件（主题 + 路由）
│   ├── router/app_router.dart    # go_router 路由表
│   ├── providers/                # 全局 Provider（主题等）
│   └── theme/                    # Material 3 主题
├── core/                         # 跨模块基础（不属任何 feature）
│   ├── constants/                # 状态色 / 尺寸 / 动效
│   ├── database/                 # Drift 数据库 + 全部表
│   ├── entities/                 # freezed 动态 JSON 实体
│   ├── platform/                 # MethodChannel 封装
│   └── widgets/                  # 通用组件
└── features/                     # 按业务域垂直切分
    ├── task/                     # 任务（P0，被主页/工作台复用）
    │   ├── domain/               # 枚举 + Repository 接口
    │   ├── data/                 # Drift 实现
    │   ├── providers/            # Riverpod Provider
    │   └── presentation/         # UI
    ├── diary/                    # 日记（P0，含 engine/ 排版引擎）
    ├── workbench/                # 工作台（P1）
    ├── toolbox/                  # 工具箱插件体系（P1）
    │   ├── birthday/  calorie/  shopping/   # 三个插件
    ├── calorie/                  # 热量共享数据源
    ├── settings/                 # 设置
    └── backup/                   # 备份恢复
```

**分层 vs 分域**：目录按 **feature（业务域）垂直切分**，每个 feature 内部再按 **layer（domain/data/providers/presentation）水平分层**。core 承载跨域共享能力。

---

## 2. Riverpod 路由结构

### 2.1 go_router 路由表

| 路由 | 页面 | 说明 |
|---|---|---|
| `/` | `HomePage` | 底部导航（主页 / 工具箱 / 设置） |
| `/diary` | `DiaryListPage` | 日记列表（按日期归档） |
| `/diary/:id` | `DiaryEditPage` | 日记详情 / 编辑（含排版引擎） |
| `/workbench` | `WorkbenchListPage` | 工作台分区列表 |
| `/workbench/:id` | `WorkbenchDetailPage` | 分区详情（任务/表格/笔记） |
| `/toolbox` | `ToolboxPage` | 扩展工具箱（插件管理） |
| `/settings` | `SettingsPage` | 设置（可在主页 tab 内，也可独立路由） |

**约定**：底部导航的 3 个 tab 用 `IndexedStack` 保持状态（已在骨架实现）；二级页面走 go_router push。V1.0 路由少，用**根级 GoRoute 平铺**即可，暂不引入嵌套 ShellRoute。

### 2.2 Provider 组织模式（每个 feature 三件套）

```dart
// 1. Repository Provider（依赖注入，实现与接口解耦）
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepositoryImpl(ref.watch(databaseProvider)),
);

// 2. 数据 Provider（响应式，DB 变化自动刷新 UI）
final taskListProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

// 3. 状态 Provider（页面/表单交互态）
final taskFormProvider = NotifierProvider<TaskFormNotifier, TaskFormState>(
  TaskFormNotifier.new,
);
```

### 2.3 状态管理约定

- **异步数据统一用 `AsyncValue`**：`when(loading/data/error)` 处理三态，UI 不手动判空。
- **响应式列表用 `StreamProvider`**：Drift 的 `watch()` 直接驱动，无需手动 `ref.refresh`。
- **跨页共享的写操作放 Repository**，页面只调用 `ref.read(repo).xxx()`，不写 SQL。
- **路由参数状态**（如 `/diary/:id`）用 go_router 的 `state.pathParameters` 传给页面，页面再据此 watch 对应的 `FutureProvider.family`。

---

## 3. 数据库模型

### 3.1 实体关系总览（ER）

```
Task ──────┐  (workbenchId，null=主页任务)
           ▼
        Workbench (1) ── configJson 内嵌子数据(表格/笔记)
           │
UserProfile (1) ── BMR 计算 ──▶ CalorieRecord（消耗/摄入）
           ▲
Task（健身完成）─ 数据联动 ─┘（写入消耗记录，非强外键）

ShoppingTemplate (1) ── templateId ──▶ ShoppingItem (n)

DiaryEntry ── contentJson ──▶ DiaryBlock[]（内嵌，不单独建表）
Birthday   ── giftHistoryJson ──▶ GiftRecord[]（内嵌）
```

**内嵌 vs 建表**：动态结构（日记区块、工作台配置、礼物历史、闹钟配置）用 **TEXT 字段存 JSON**；稳定且需查询/统计的实体（任务、热量、采购、生日、工作台）**单独建表**。

### 3.2 数据字典（逐实体字段）

**Task 任务**（健身/学习共用，type 区分）

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | long | PK 自增 | |
| type | enum | fitness/study | 任务类型 |
| title | string | 1-200 | 标题 |
| repeatMode | enum | once/daily/weekly | 重复模式 |
| repeatDays | string? | "1,3,5" | 每周固定日 |
| status | enum | todo/inProgress/done | 三态 |
| totalSeconds | int | 默认 0 | 累计耗时（秒） |
| startedAt | datetime? | | 计时开始（后台真源） |
| alarmConfig | json? | | 闹钟配置 JSON |
| calorie | int | 默认 0 | 健身消耗热量 |
| workbenchId | long? | FK→Workbench | null=主页任务 |
| createdAt | datetime | | |
| completedAt | datetime? | | |

**Workbench 工作台分区**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | long PK | |
| name | string | 分区名 |
| icon | string | 图标 |
| mode | enum | task/table/note |
| configJson | json | 表格行列配置 / 笔记内容 |
| sortOrder | int | 排序 |

**DiaryEntry 日记**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | long PK | |
| title | string? | |
| date | datetime | 归档日期 |
| template | enum | ruled/blank |
| cover | string? | 封面相对路径 |
| contentJson | json | DiaryBlock 列表 |
| updatedAt | datetime | 自动保存时间戳 |

**Birthday 朋友生日**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | long PK | |
| name | string | |
| calendarType | enum | solar/lunar |
| birthMonth / birthDay | int | 公历或农历月日 |
| remindDays | int | 提前 1/3/7 天 |
| group | string? | 同学/好友/家人 |
| note | string? | 喜好/忌口备注 |
| giftHistoryJson | json | 礼物历史数组 |

**UserProfile 用户画像（BMR 用）**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | long PK | |
| gender | enum | male/female |
| height / weight | double | cm / kg |
| age | int | |
| activityFactor | double | 活动系数 |

**CalorieRecord 热量记录**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | long PK | |
| date | datetime | 当日 |
| type | enum | intake/expenditure |
| source | enum | meal/健身/手动/步数 |
| amount | int | 千卡 |
| note | string? | |

**ShoppingItem 采购条目**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | long PK | |
| templateId | long? | FK→ShoppingTemplate |
| name | string | |
| quantity | double | 数量 |
| unit | string? | 单位 |
| category | string? | 分类 |
| purchased | bool | 已购沉底 |
| sortOrder | int | 拖拽排序 |

**ShoppingTemplate 采购模板**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | long PK | |
| name | string | 模板名 |
| itemsJson | json | 条目列表快照 |

**AppSetting 设置（键值）**

| 字段 | 类型 | 说明 |
|---|---|---|
| key | string PK | |
| value | string | 序列化值 |

### 3.3 Drift 表定义（核心代码）

```dart
// 任务表（示例，其余表同理）
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text().withLength(min: 1, max: 16)();       // fitness/study
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get repeatMode => text().withLength(min: 1, max: 16)(); // once/daily/weekly
  TextColumn get repeatDays => text().nullable()();                  // "1,3,5"
  TextColumn get status => text().withLength(min: 1, max: 16)();     // todo/inProgress/done
  IntColumn get totalSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime().nullable()();
  TextColumn get alarmConfig => text().nullable()();                 // JSON
  IntColumn get calorie => integer().withDefault(const Constant(0))();
  IntColumn get workbenchId => integer().nullable()();               // FK→Workbench
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
```

**枚举存字符串**：`type/status/repeatMode` 用 `enum.name` 存、`Enum.values.byName` 读，避免魔数。

### 3.4 Isar collection 映射（备选对照）

若坚持 Isar（锁定 `isar_community` 3.3.2），每个 Drift 表对应一个 `@collection`：

| Drift 表 | Isar collection | 差异点 |
|---|---|---|
| Tasks | `@collection class Task` | 用 `@Index` 建 `status`/`type`/`workbenchId` 索引；`Id id = Isar.autoIncrement` |
| Workbench | `@collection class Workbench` | `configJson` 存 String |
| DiaryEntry | `@collection class DiaryEntry` | 用 `@Index(IndexType.value)` 建 `date` 索引，支持全文搜索 |
| Birthday / CalorieRecord / ShoppingItem / ... | 同名 collection | 字段一致 |

**切换成本**：仅改动 `*_repository_impl.dart` 的数据访问实现，Domain 接口、State、UI 全部不变——这正是 Repository 接口隔离的价值。

### 3.5 动态 JSON 字段设计

| JSON 字段 | 承载实体（freezed） | 说明 |
|---|---|---|
| `Task.alarmConfig` | `AlarmConfig` | 已实现 |
| `DiaryEntry.contentJson` | `DiaryBlock[]` | 已实现（text/image/video 三态 union） |
| `Workbench.configJson` | `TableConfig` / 笔记内容 | 待定义 |
| `Birthday.giftHistoryJson` | `GiftRecord[]` | 待定义 |
| `ShoppingTemplate.itemsJson` | `ShoppingItem[]` 快照 | 待定义 |

**原则**：可变/动态结构用 JSON + freezed 生成不可变实体；稳定且需高频查询/统计的字段拆成表列。媒体文件一律存相对路径，**严禁 Base64 入库**。

---

## 4. 关键决策速查

| 决策 | 结论 |
|---|---|
| 数据库 | Drift (SQLite)，Isar 备选（见 ADR-001） |
| 状态管理 | Riverpod 3.x 手写 Provider，AsyncValue 统一 |
| 路由 | go_router，根级平铺 + 底部导航 IndexedStack |
| 分层 | 5 层，依赖单向向下 + Domain 依赖倒置 |
| 动态数据 | TEXT 存 JSON + freezed 实体 |
| 媒体 | 相对路径，禁 Base64 |

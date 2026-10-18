# UI 设计规范 · 实现版

> 适用工程：`efficiency_app_wb`（Flutter / Android，v1.0.0+1）
> 上位约束：`F:\develop\mailbox\UI验收标准.md`（R1–R3 / D1–D7）。**本文件与它冲突时，以验收标准为准。**
> 本文只描述「页面长什么样、每个控件点下去发生什么」，不改任何 `.dart` 代码。
> 单一实现依据：**本文件**。旧的 `docs/ui_design_spec.md` 为简版草稿，请以本文为准（处置见 §8 C7）。

---

## 0. 阅读顺序与优先级

| 优先级 | 内容 | 章节 |
|---|---|---|
| P0 | 设置页 4 区块（R1 假控件清零 + D1/D2/D3） | §2 |
| P0 | 任务列表 `TaskTile` 重排（当前右侧 3 个按钮挤压标题） | §4 |
| P0 | 工具箱 3 张插件卡（R2 合规） | §3 |
| P1 | 新建任务独立页（修掉「每周选不了日 → 任务永不生成」） | §5 |
| P1 | 状态色 / 行动入口 / SnackBar 反馈（D4/D5/D6） | §6 |
| P2 | token 自检（D7）、三态补齐（R3） | §7 / §4.7 |

**先修 §8 C1（编译错误），否则整包起不来，其余都是空谈。**

---

## 1. 设计体系映射（不要另造组件）

### 1.1 组件职责表（`lib/core/widgets/ui_kit.dart`）

| 场景 | 组件 | 必填参数 | 说明 |
|---|---|---|---|
| 区块标题 | `AppSectionHeader(title, subtitle?)` | title | 主题色小标题，上 8 / 下 6 |
| 一组设置行 | `AppCard.group(children: [...])` | children | 自动插缩进分隔线（indent 56），卡片间距 12 |
| 纯展示行 | `AppSettingsTile(icon,title,subtitle)` | 全部 | 不可点 |
| 可点击行 | `AppActionTile(icon,title,subtitle,onTap)` | 全部 | 右侧自动 `chevron_right` |
| 开关行 | `AppSwitchTile(icon,title,value,onChanged,subtitle,subtitleOnEnabled?,subtitleOnDisabled?)` | 全部 | `onChanged` 编译期必填，**天然满足 R1** |
| 状态行 | `AppStatusTile(icon,title,subtitle,ok,trailing?)` | 全部 | `ok=false` → 橙色 + `warning_amber_rounded` |
| 未实现行 | `AppDisabledTile(icon,title,reason?)` | icon/title | 灰化 + `尾标 "未开放"`，默认 reason `后续迭代开放` |

### 1.2 用法硬约束

1. 设置页**禁止**直接写 `ListTile` / `SwitchListTile`，一律走上面 7 个组件。
2. 一个 `AppCard` 内 ≥2 行时才用 `AppCard.group`；单行用 `AppCard(child: ...)`。
3. 「行 + 行下方控件」（Slider / SegmentedButton）必须**合并成一个 child**，否则 `AppCard.group` 会在中间插一条 indent 56 的分隔线，视觉断裂。写法：

```dart
AppCard.group(children: [
  Column(children: [
    AppSettingsTile(icon: Icons.volume_up_outlined, title: '默认音量', subtitle: '新建闹钟默认音量 80%'),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding)
          .copyWith(bottom: AppDimens.sectionHeaderGap),
      child: Slider(...),
    ),
  ]),
  // 下一行...
])
```

---

## 2. 设置页（`lib/features/settings/presentation/settings_page.dart`）

### 2.1 页面骨架

```dart
Scaffold(
  appBar: AppBar(title: const Text('设置')),
  body: ListView(
    padding: const EdgeInsets.only(bottom: AppDimens.pagePadding),
    children: [
      const AppSectionHeader('通用', subtitle: '外观与新建任务的默认值'),
      AppCard.group(children: [ /* 2 行 */ ]),
      const AppSectionHeader('提醒', subtitle: '关闭总开关后，所有任务都不会响铃'),
      AppCard.group(children: [ /* 6 行 */ ]),
      const AppSectionHeader('数据与备份', subtitle: '数据只存在本机，不上传服务器'),
      AppCard.group(children: [ /* 4 行 */ ]),
      const AppSectionHeader('关于', subtitle: null),
      AppCard.group(children: [ /* 4 行 */ ]),
    ],
  ),
)
```

- `ListView` **不要**加 `horizontal` padding（`AppCard` 自带 `pagePadding` 外边距，加了会变 32）。
- 区块顺序固定为 通用 → 提醒 → 数据与备份 → 关于。
- AppBar 右上角**不放**任何操作（避免出现无实现的按钮）。

### 2.2 区块一：通用

| # | 行标题 | 图标 | 控件 | subtitle（**按状态给不同文案**） | 点击后发生什么（真实效果） |
|---|---|---|---|---|---|
| 1 | 主题模式 | `Icons.brightness_6_outlined` | `AppSettingsTile` + 行下 `SegmentedButton<ThemeMode>`（3 段：系统 / 浅色 / 深色） | 系统 → `浅色/深色随系统设置自动切换`<br>浅色 → `始终使用浅色界面`<br>深色 → `始终使用深色界面` | `ref.read(themeModeProvider.notifier).setMode(mode)` → 写 `app_settings.json` 的 `themeMode`，**整包立即换肤**（已有实现） |
| 2 | 默认重复规则 | `Icons.repeat` | `AppSettingsTile` + `trailing: DropdownButton<String>`（3 项：单次 / 每日 / 每周固定日） | 单次 → `新建任务默认选中「单次」`<br>每日 → `新建任务默认选中「每日」`<br>每周 → `新建任务默认选中「每周固定日」` | `patch(defaultRepeatMode: 'once'/'daily'/'weekly')` → 落盘；**新建任务页的重复选项初始值改为读这个值**（§5.4，这是它"不是假控件"的证据） |

`SegmentedButton` 参数（必须，否则 360dp 屏溢出）：

```dart
SegmentedButton<ThemeMode>(
  segments: const [
    ButtonSegment(value: ThemeMode.system, label: Text('系统')),
    ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
    ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
  ],
  selected: {mode},
  showSelectedIcon: false,
  expandedInsets: EdgeInsets.zero,   // 铺满卡片内容宽
  onSelectionChanged: (s) => ...,
)
```

> 为什么不用 `ListTile.trailing` 塞 SegmentedButton：360dp 屏下可用 trailing 宽约 120dp，3 段中文约 192dp，**必然溢出**（见 §8 C8）。

### 2.3 区块二：提醒

| # | 行标题 | 图标 | 控件 | subtitle 态 A / 态 B | 点击后发生什么 |
|---|---|---|---|---|---|
| 3 | 任务提醒 | `Icons.notifications_active_outlined` | `AppSwitchTile` | 开 → `所有任务闹钟会按时响铃`<br>关 → `已关闭全部闹钟，到点也不会响` | `ref.read(reminderSwitchProvider).setEnabled(v)`：<br>关 → `setAllEnabled(false)` 落库 + 逐个 `cancel(taskId)`，SnackBar `已关闭全部提醒（共 N 个）`<br>开 → `setAllEnabled(true)` + `rescheduleAll()`，SnackBar `已开启提醒，已重排 N 个闹钟`<br>**失败** → 开关回弹到原值 + SnackBar `操作失败，请重试`（禁止静默失败） |
| 4 | 精确闹钟 | `Icons.alarm_on` | `AppStatusTile(ok: canExact)` | true → `闹钟将准时响铃，误差通常在 1 分钟内`<br>false → `未授权精确闹钟，系统可能延迟几分钟响铃` | `ok=false` 时 `trailing: TextButton('去开启')` → `AlarmScheduler.requestExactAlarmPermission()`；**回到前台后 `ref.invalidate(exactAlarmAllowedProvider)` 重新读状态**（回前台不刷新＝状态是假的） |
| 5 | 贪睡 | `Icons.snooze` | `AppSwitchTile` | 开 → `闹钟响起后可再睡 ${n} 分钟`<br>关 → `闹钟响后不重复提醒` | `patch(snoozeEnabled:)` → 落盘；**新建闹钟的 `snoozeEnabled` 默认值取此值** |
| 5b | 贪睡间隔 | `Icons.timer_outlined` | `AppSettingsTile` + `trailing: DropdownButton<int>`（5 / 10 / 15 / 20 分钟），**仅当 #5 开启时显示** | `贪睡后 ${n} 分钟再次响铃` | `patch(snoozeMinutes:)` → 落盘 + #5 的 subtitle 同步变 |
| 6 | 默认铃音 | `Icons.music_note` | `AppSettingsTile` + `trailing: DropdownButton<String>`（3 项，见 §8 C2） | `新建闹钟默认使用「${label}」` | `patch(ringtone: id)` → 落盘；**新建闹钟的 `ringtone` 默认值取此值** |
| 7 | 默认音量 | `Icons.volume_up_outlined` | `AppSettingsTile` + 行下 `Slider(min: 10, max: 100, divisions: 18)` | `新建闹钟默认音量 ${v}%` | `patch(volume: v.round())`（**拖动中不写盘，`onChangeEnd` 才写**，避免每秒写文件）；新建闹钟 `volume` 取此值 |
| 8 | 免打扰时段 | `Icons.do_not_disturb_on_outlined` | `AppDisabledTile` | reason：`后续迭代开放：可在指定时段内静音全部提醒` | 无（灰化，不可点） |

**区块内不出现**：试听按钮、通知权限开关（未实现则一律 `AppDisabledTile`，禁止"点了调个空方法"）。

### 2.4 区块三：数据与备份

| # | 行标题 | 图标 | 控件 | subtitle | 点击后发生什么 |
|---|---|---|---|---|---|
| 9 | 今日概览 | `Icons.insights_outlined` | `AppSettingsTile`（只读） | 有数据 → `共 ${total} 项 · 已完成 ${done} 项 · 进行中 ${doing} 项`<br>无数据 → `今天还没有任务`<br>加载中 → `正在统计…` | 无交互（数据来自 `todayInstancesProvider`） |
| 10 | 清理今日已完成 | `Icons.cleaning_services_outlined` | `AppActionTile`；`doneCount == 0` 时**降级为** `AppDisabledTile(reason: '今天还没有已完成的任务')` | `从今日列表移除 ${doneCount} 条已完成任务（历史记录保留）` | 确认框（标题 `清理已完成任务`，正文 `将移除 ${doneCount} 条已完成任务，历史记录仍保留。`，按钮 `取消` / `清理`(danger 色)）→ 逐条 `deleteInstance(id)` → SnackBar `已清理 ${doneCount} 条` |
| 11 | 导出数据 | `Icons.upload_file_outlined` | `AppDisabledTile` | reason：`后续迭代开放：把任务与设置导出为 JSON 文件` | 无 |
| 12 | 从备份恢复 | `Icons.settings_backup_restore` | `AppDisabledTile` | reason：`后续迭代开放：从本地 JSON 备份文件恢复数据` | 无 |

> #10 用软删除（`deleteInstance`），所以文案写「历史记录保留」是准确的，**不要**写成「永久删除」。#11/#12 任何"先做个假按钮"的冲动都必须压住。

### 2.5 区块四：关于

| # | 行标题 | 图标 | 控件 | subtitle | 点击后发生什么 |
|---|---|---|---|---|---|
| 13 | 版本 | `Icons.info_outline` | `AppSettingsTile` | `v1.0.0+1`（取自 `kAppVersion` 常量） | 无 |
| 14 | 开源许可 | `Icons.description_outlined` | `AppActionTile` | `查看本应用使用的第三方开源组件与许可证` | `showLicensePage(context: context, applicationName: '效率工具', applicationVersion: kAppVersion)`（Flutter 内置，零依赖，**真页面**） |
| 15 | 隐私政策 | `Icons.privacy_tip_outlined` | `AppDisabledTile` | reason：`后续迭代开放：需先引入外部链接能力` | 无 |
| 16 | 意见反馈 | `Icons.feedback_outlined` | `AppDisabledTile` | reason：`后续迭代开放：需先引入外部链接能力` | 无 |

**版本号来源**：工程无 `package_info_plus`。#13 用常量 `lib/core/constants/app_info.dart`：

```dart
/// 与 pubspec.yaml 的 version 保持一致（改版本时两处一起改）。
const String kAppVersion = '1.0.0+1';
```

（备选：引入 `package_info_plus` 动态读取。本迭代**不要**为一个版本号加依赖，但要接受"忘记同步"的代价。）

### 2.6 设置页 R1 自查表（交付时必须附此表，逐个控件）

| 控件 | 位置 | 点击后 |
|---|---|---|
| 主题 3 段按钮 | 通用 | 写 `themeMode`，整包换肤并落盘 |
| 默认重复规则下拉 | 通用 | 写 `defaultRepeatMode`，新建任务页初始值改变 |
| 任务提醒开关 | 提醒 | `setAllEnabled` + cancel/rescheduleAll + SnackBar；失败回弹 |
| 去开启（精确闹钟） | 提醒 | 跳系统「闹钟和提醒」设置页，回前台重新读状态 |
| 贪睡开关 | 提醒 | 写 `snoozeEnabled`，控制 #5b 显隐 |
| 贪睡间隔下拉 | 提醒 | 写 `snoozeMinutes`，同步 #5 文案 |
| 默认铃音下拉 | 提醒 | 写 `ringtone`，新建闹钟默认值改变 |
| 默认音量滑块 | 提醒 | `onChangeEnd` 写 `volume`，新建闹钟默认值改变 |
| 清理今日已完成 | 数据与备份 | 确认后软删今日已完成实例 + SnackBar |
| 开源许可 | 关于 | 打开 `showLicensePage` |
| 其余 5 行（免打扰 / 导出 / 恢复 / 隐私 / 反馈） | — | **不可点**（`AppDisabledTile`，enabled:false） |

### 2.7 设置页需要的支撑代码

| 名称 | 类型 | 位置 | 职责 |
|---|---|---|---|
| `exactAlarmAllowedProvider` | `FutureProvider<bool?>` | `lib/features/settings/providers/alarm_permission.dart`（新建） | `try { return await AlarmScheduler.canScheduleExactAlarms(); } catch (_) { return null; }` |
| 生命周期刷新 | `WidgetsBindingObserver` | `settings_page.dart` | `didChangeAppLifecycleState == resumed` → `ref.invalidate(exactAlarmAllowedProvider)` |
| 设置页三态 | — | 同上 | `null`（读不到系统状态，如非 Android）→ 该行渲染为 `AppActionTile(icon: Icons.help_outline, title: '精确闹钟', subtitle: '无法读取系统状态，点此重试', onTap: invalidate)`；`loading` → 同标题 `subtitle: '正在读取…'` |

> 设置页**没有**列表型远程数据，契约的「空态/加载态」只作用于 #4 与 #9 两行，**不要**为整页加骨架屏。

---

## 3. 工具箱（`lib/features/toolbox/presentation/toolbox_page.dart`）

### 3.1 合规判定（R2）

R2 允许占位页存在，但**页面内必须写明「开发中」**。当前页面只有一句 `EmptyState`，三个插件功能一个都没写清，用户看完不知道这几个插件是干什么的 —— 属于"擦边合规"。

改造原则：

| 规则 | 做法 |
|---|---|
| 不许假装能开 | 卡片**不挂 `onTap`、不挂 `InkWell`、不加 `chevron_right`**，视觉上不是可点击行 |
| 必须写「开发中」 | 每张卡片右上角固定灰 chip `开发中`，且副文案里明确 `暂不可用` |
| 不能空白 | 每张卡片必须给出「一句话价值 + 规划能力」，让用户知道建成后是什么 |
| 不许放假开关 | **不出现**「添加到主页」按钮、任何 Switch |

静态卡片的状态（只读）不违反 R1 —— R1 管的是「看起来能点、点了没反应」，不是「必须有控件」。

### 3.2 页面结构

```
AppBar(title: '工具箱')
ListView(
  AppSectionHeader('插件', subtitle: '默认不启用以保持主页清爽，上线后可一键添加到主页'),
  卡片 × 3（间距 AppDimens.cardGap）
  SizedBox(height: AppDimens.sectionGap)
  Padding(水平 pagePadding, Text('以上插件均为独立模块：未启用时不申请权限、不占后台资源、不读取你的数据。', bodySmall + outline))
)
```

**不要 AppBar action，不要 FAB。**

### 3.3 插件卡规格（三张共用）

| 项 | 值 |
|---|---|
| 容器 | `Container`，`margin: EdgeInsets.symmetric(horizontal: AppDimens.pagePadding, vertical: AppDimens.cardGap / 2)`，`padding: EdgeInsets.all(AppDimens.pagePadding)` |
| 装饰 | `surfaceContainerLow` 底色 + `BorderRadius.circular(AppDimens.cardRadius)` + `Border.all(outlineVariant, width: 0.8)`（与 `AppCard` 完全一致） |
| 布局 | `Row(crossAxisAlignment: start)`：图标 44×44 → 间距 12 → `Expanded(Column)` |
| 图标容器 | 44×44，`BorderRadius.circular(AppDimens.cardRadius)`，底色 = 该插件主色 `withValues(alpha: 0.12)`，图标 22 |
| 标题行 | `Text(title, style: titleMedium.copyWith(fontWeight: w600))` + 间距 8 + 灰 chip `开发中` |
| 一句话价值 | `bodySmall` + `onSurfaceVariant`，**最多 1 行**（`maxLines: 1, overflow: ellipsis`） |
| 规划能力 | `bodySmall` + `outline`，前缀 `规划：`，可 2 行 |
| 交互 | 无（不包 `InkWell`） |

### 3.4 三个插件的文案（原文，照抄）

| 插件 | 图标 | 主色 | 一句话价值（subtitle） | 规划能力（第三行） | 状态 |
|---|---|---|---|---|---|
| 朋友生日 | `Icons.cake_outlined` | `AppColors.warning` | `记录生日与农历日期，提前提醒，不再临时补礼物` | `规划：公历/农历生日、提前 7 天与当天提醒、生日距离倒数` | chip `开发中` |
| 每日热量 | `Icons.local_fire_department_outlined` | `AppColors.danger` | `按分钟记录运动消耗，和健身任务自动挂钩` | `规划：任务时长 × 每分钟消耗、每日目标进度、周汇总` | chip `开发中` |
| 采购清单 | `Icons.shopping_cart_outlined` | `AppColors.active` | `随手记要买的东西，到超市一次性勾完` | `规划：清单分组、勾选即归档、与提醒联动` | chip `开发中` |

页面底部固定说明文案（原文）：

> `以上插件均为独立模块：未启用时不申请权限、不占后台资源、不读取你的数据。`

### 3.5 R2 / R1 证据怎么给（截图要求）

- 截图必须**同时**出现：3 张卡片 + 3 个 `开发中` chip + 底部说明 → 证明"占位但已告知"。
- 逐个点击卡片 → **无任何反应是预期且合规的**（因为不是可点击组件）；若实现者给卡片加了 `InkWell`，就必须有真实落地页，否则直接判 R1 违规。

---

## 4. 任务列表（`task_list_page.dart` + `widgets/task_tile.dart`）

### 4.1 现状问题清单（按严重度）

| # | 问题 | 证据 | 用户感受 |
|---|---|---|---|
| P1 | 右侧塞了 3 个 `IconButton`（闹钟 / 完成 / 删除），合计约 144dp | `task_tile.dart:47-71` | 360dp 屏上卡片内宽约 328dp，减去 leading 40 + 3 个按钮 144 + 内边距 16×2，标题只剩 **~96dp**，**中文标题 5 个字就换行** |
| P2 | 「已设闹钟」用 `AppColors.warning` 橙色 | `task_tile.dart:55` | 橙色在本系统里是「警告/未授权」的语义，这里实际是**正常状态**，语义反了（D4 违规） |
| P3 | 删除按钮常驻、紧挨完成按钮 | `task_tile.dart:65-69` | 高频操作旁 24dp 就是不可逆删除，误触成本极高 |
| P4 | 未完成态标题用默认色（近黑），但状态图标是灰 | `task_tile.dart:88-90` | 一眼看过去只有图标是灰的，整行并不"呈现未完成"，三态区分弱 |
| P5 | 卡片间距用硬编码 `EdgeInsets.only(bottom: 8)` | `task_list_page.dart:171` | 8 不在设计刻度里（应为 12），列表比设置页更挤（D7） |
| P6 | 列表 padding 写死 `EdgeInsets.all(16)`，末条被 FAB 遮住 | `task_list_page.dart:165` | 滚到底时最后一张卡的一部分在 FAB 下面 |
| P7 | 已完成行 `onTap: null`，但仍沿用 `ListTile` 的可点外观 | `task_tile.dart:43` | 点不动又像能点，容易判定为"假控件" |
| P8 | 删除确认框的确认按钮是主题色 `FilledButton('删除')` | `task_list_page.dart:46-49` | 破坏性操作用了正向色，视觉上"鼓励删除" |
| P9 | 进行中只写「计时中」三个字，不显示已计时长 | `task_tile.dart:108` | 用户无法判断"我练了多久"，而数据（`accumulatedSeconds`/`startedAt`）本来就有 |
| P10 | 错误态只有图标 + 文案，没有重试 | `task_list_page.dart:151-155` | R3 明确要求「错误态给可重试入口」，当前不达标 |

### 4.2 目标结构（照此实现）

```
Card                                    ← 复用 cardTheme（radius 12 / elevation 0）
│ margin: EdgeInsets.only(bottom: AppDimens.cardGap)
│ color: surfaceContainerLow, 细边框 outlineVariant 0.8（与 AppCard 一致）
└ InkWell                              ← 仅 todo / inProgress 挂；done 传 null
  └ Padding(all: AppDimens.cardGap)
    └ Row(crossAxisAlignment: center)
      ├ 状态图标 40×40（宽 = AppDimens.leadingIconWidth 对齐设置页）
      ├ SizedBox(width: AppDimens.cardGap)
      ├ Expanded(Column(start))
      │   ├ Text(title, maxLines: 2, ellipsis)
      │   └ SizedBox(height: AppDimens.cardPadding)
      │   └ Text.rich(subtitle)
      ├ SizedBox(width: AppDimens.sectionHeaderGap)
      ├ [非 done] IconButton(Icons.check_circle_outline, color: success, tooltip: '完成')
      └ PopupMenuButton<int>(Icons.more_vert, tooltip: '更多')
```

宽度核算（360dp 屏）：328 卡宽 − 24 内边距 − 40 图标 − 12 间距 − 8 间距 − 48 完成 − 48 更多 ≈ **148dp**，比现状多 60%，标题可容 7 个汉字不换行。

### 4.3 状态编码（D4，逐项落地）

| 状态 | leading 图标 | 容器底色 | 标题 | subtitle | 右动作 |
|---|---|---|---|---|---|
| 未完成 `todo` | `Icons.radio_button_unchecked`，色 `AppColors.todo` | **不填充**（透明） | `bodyLarge`，色 `onSurface` | `学习` / `健身`（+ 闹钟） | 完成 ✓ + 更多 ⋮ |
| 进行中 `inProgress` | `Icons.play_circle_fill`，色 `AppColors.active` | `active.withValues(alpha: 0.12)` | `bodyLarge`，色 `AppColors.active`，`w600` | `计时中 12:34 · 学习`（"计时中" 用 active 色）+ 闹钟 | 完成 ✓ + 更多 ⋮ |
| 已完成 `done` | `Icons.check_circle`，色 `AppColors.success` | `success.withValues(alpha: 0.12)` | `bodyLarge`，色 `onSurfaceVariant`，`lineThrough` | `学习 · 用时 25 分钟` | 仅 更多 ⋮ |

- **只有"状态存在"时才填底色**：灰底 + 灰图标会像"禁用"，所以 todo 不填底色，靠描边图标表达"未开始"。
- 标题色规则：`todo` 用 `onSurface`（**不用** `AppColors.todo`，见 §8 C4），`inProgress` 用 `active`，`done` 用 `onSurfaceVariant` + 删除线。
- 图标容器尺寸统一 32×32、圆角 `cardRadius`，外层占位宽 `AppDimens.leadingIconWidth`，保证与设置页图标列**左右对齐**。

### 4.4 副标题与闹钟标识

```dart
Text.rich(TextSpan(children: [
  if (status == TaskStatus.inProgress)
    TextSpan(text: '计时中 ${mmss} · ', style: TextStyle(color: AppColors.active)),
  if (alarm != null) ...[
    WidgetSpan(child: Icon(Icons.alarm, size: 14, color: AppColors.success)),
    TextSpan(text: ' ${alarm!.timeLabel} · '),
  ],
  TextSpan(text: typeLabel),                       // 学习 / 健身
  if (status == TaskStatus.done)
    TextSpan(text: ' · 用时 ${(instance.accumulatedSeconds / 60).round()} 分钟'),
]))
```

- 闹钟图标改 `AppColors.success`（**不再用 warning**，见 P2）；未设闹钟时**不显示**任何闹钟痕迹（现状每行都有个灰色 `alarm_add`，制造噪声）。
- `计时中` 的 `mm:ss`：`accumulatedSeconds + (now - startedAt)`，用一个 `Stream.periodic(1s)` 的私有小组件每秒重建；若实现成本超预算，**降级为只显示「计时中」**，但不得显示错误时长。

### 4.5 动作区（P3）

| 动作 | 入口 | 说明 |
|---|---|---|
| 完成 | 右侧 `IconButton(check_circle_outline)`，`AppColors.success`，tooltip `完成` | 只有一个主操作，且不挨着删除 |
| 编辑闹钟 / 删除 | `PopupMenuButton<int>`（`Icons.more_vert`，tooltip `更多`） | 菜单项按序：`编辑闹钟`（`Icons.alarm`，`alarm == null` 时文案 `设置闹钟`）→ `删除`（`Icons.delete_outline`，`foregroundColor: AppColors.danger`）；`done` 行只保留 `删除`（无"撤销完成"接口，不要伪造） |

删除确认框（P8 修正）：

| 项 | 规格 |
|---|---|
| 标题 | `删除任务` |
| 正文 | `删除后「${title}」将从今日列表移除，历史记录仍保留。` |
| 取消 | `TextButton('取消')` |
| 确认 | `FilledButton` + `styleFrom(backgroundColor: AppColors.danger, foregroundColor: theme.colorScheme.onPrimary)`，文案 `删除` |

### 4.6 列表容器（P5 / P6）

```dart
ListView.builder(
  padding: const EdgeInsets.fromLTRB(
    AppDimens.pagePadding, AppDimens.sectionHeaderGap,
    AppDimens.pagePadding, AppDimens.minTapSize * 2,   // 给 FAB 留出空间，避免遮挡末条
  ),
  ...
)
```

顶部只留 8（卡片自身还有 6 的 `margin`，合计 14），与设置页区块标题下的留白一致；删除 `task_list_page.dart:170-172` 那层 `Padding(bottom: 8)` —— 间距交给 `Card.margin`（12），避免"卡片间距 8 / 其他页 12"的两套刻度。

### 4.7 三态（R3，含 P10 修复）

| 态 | 现状 | 改成 |
|---|---|---|
| 加载 | `Center(CircularProgressIndicator())` | 保持（可加 `padding` 不影响） |
| 空 | `EmptyState(task_alt, '今日暂无任务', '点击右下角 + 创建你的第一个任务')` | 文案改 `今天还没有任务` / `点右下角 + 新建第一个任务，或到工具箱添加插件` |
| 错误 | `EmptyState(error_outline, '加载失败', '$e')` — **无重试** | `EmptyState(..., action: TextButton.icon(Icons.refresh, '重试', onPressed: () => ref.invalidate(todayInstancesProvider)))`（需给 `EmptyState` 加可选 `action`，见 §8 C6） |

### 4.8 今日进度卡（列表首条，随列表滚动）

AppBar 只保留文字 `今日任务`（**不再放日期**，日期归进度卡，避免同一信息出现两次）。

放在 `ListView` 的第 0 项（不做固定 header，滚动时让位给内容），视觉与 `AppCard` 完全一致：

| 区域 | 规格 |
|---|---|
| 容器 | `margin: EdgeInsets.symmetric(horizontal: pagePadding, vertical: cardGap / 2)`，`padding: EdgeInsets.all(pagePadding)`，`surfaceContainerLow` 底 + `cardRadius` 圆角 + `outlineVariant` 0.8 描边 |
| 第一行 | 左：日期 `${m}月${d}日 ${week}`（`bodySmall` + `onSurfaceVariant`）；右：`${done}/${total}`（`titleSmall` + `w600`，**全部完成时用 `AppColors.success`**） |
| 进度条 | `LinearProgressIndicator(value: done / total, minHeight: AppDimens.sectionHeaderGap, borderRadius: BorderRadius.circular(AppDimens.cardPadding), color: AppColors.success, backgroundColor: surfaceContainerHighest)` —— 高度取 8、圆角取 4，均为 token |
| 第三行 | 0 项 → `今天还没有任务`<br>`0 < done < total` → `还差 ${total - done} 项，已完成 ${percent}%`<br>`done == total` → `今天的任务都完成了，休息一下`（`AppColors.success` + `Icons.check_circle` 16） |
| 数据 | `todayInstancesProvider`：`total = list.length`，`done = where(done).length`；`loading` → 进度条 `value: null`（原生的不确定态）+ 文案 `正在统计…`；`error` → 整卡不渲染（错误由下方列表的错误态承载，避免两处报错） |

`week` 用 `const ['周一','周二','周三','周四','周五','周六','周日'][weekday - 1]`，**不要**用 `DateFormat`（未初始化 locale 会抛异常）。

---

## 5. 新建任务页（新增 `lib/features/task/presentation/add_task_page.dart`）

### 5.1 为什么独立页优于对话框（评审方问过，这是答案）

| 维度 | 当前对话框（`task_list_page.dart:57-122`） | 独立页 |
|---|---|---|
| **功能正确性** | `addTemplate` 的 `repeatDays` 默认 `const []`，而 `backfill.dart:35` 要求 `repeatDays.contains(weekday)` → **选「每周固定日」创建的任务永远不会生成**（真 bug，不是审美问题） | 页内有 7 个星期 chip，能真实传入 `repeatDays` |
| 键盘 | 5 英寸屏 + 键盘 = 可用高 < 400dp，`AlertDialog.content` 不滚动，必然溢出；`TextField` + `SegmentedButton` + `Dropdown` 叠在一起，输入法一弹就黄黑条 | 整页 `ListView` 可滚，键盘只顶起底部按钮 |
| 条件展开 | 「每周」要露出选日，「设闹钟」要露出时间，对话框里得靠 `StatefulBuilder` 手动 `setState`，容易漏 | 页内 `setState` 语义清晰，展开/收起有 `AnimatedSize` |
| 误触成本 | 点对话框外部即关闭，输入全丢 | 有 `取消`/系统返回，且**有输入时二次确认**（`放弃创建？`） |
| 扩展性 | 再加「备注/标签/提前提醒」就得重排对话框 | 只是一段新的 `AppCard.group` |
| 可达性 | 对话框不能深链、不能从通知直接跳入 | 路由 `/task/new` 可深链（`app_router.dart` 注释里本来就预留了扩展） |
| 拇指区 | 确认按钮在对话框底部，键盘弹起后被顶到屏幕中部 | 主按钮固定在底部 `SafeArea`，永远在拇指区 |

结论：**新增页面，删除对话框**（`_showAddDialog` 整体移除）。

### 5.2 页面骨架

```dart
Scaffold(
  appBar: AppBar(
    leading: IconButton(Icons.close, tooltip: '取消', onPressed: _confirmDiscard),
    title: const Text('新建任务'),
    actions: [TextButton(onPressed: _canSave ? _save : null, child: const Text('保存'))],
  ),
  body: ListView(padding: EdgeInsets.only(bottom: AppDimens.pagePadding), children: [...]),
  bottomNavigationBar: SafeArea(child: Padding(
    padding: const EdgeInsets.fromLTRB(AppDimens.pagePadding, AppDimens.sectionHeaderGap,
        AppDimens.pagePadding, AppDimens.pagePadding),
    child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _canSave ? _save : null, child: Text('创建任务'))),
  )),
)
```

- FAB 改为 `context.push('/task/new')`（在 `app_router.dart` 增加 `GoRoute(path: '/task/new', builder: ...)`；备选 `Navigator.push`）。
- 顶部 `保存` 与底部 `创建任务` 同源同一个 `_save`（两处都做，是安卓用户的双习惯，不是重复设计）。
- 按钮禁用时必须给**原因文案**，见 5.3。

### 5.3 信息层级（3 组，顺序固定）

**组一 · 基本信息**

| 字段 | 组件 | 图标 | 文案 | 规则 |
|---|---|---|---|---|
| 任务标题 | `TextField`（卡片内，`prefixIcon: Icons.edit_note`） | `Icons.edit_note` | label `任务标题`，hint `例如：晨跑 30 分钟`，counter `0/40` | `autofocus: true`；`maxLength: 40`；`textInputAction: done`；空 → `errorText: '请输入任务标题'` |
| 任务类型 | `AppSettingsTile`（subtitle 显示当前选择）+ 行下 `SegmentedButton<TaskType>` | 选中项动态：学习 `Icons.menu_book`，健身 `Icons.fitness_center` | 学习 → `记录学习时长，完成后归档`；健身 → `记录运动时长，可计算消耗` | 2 段：`学习` / `健身`，`showSelectedIcon: false`，`expandedInsets: EdgeInsets.zero`（默认 `study`） |

**组二 · 重复**

| 字段 | 组件 | 图标 | 文案 | 规则 |
|---|---|---|---|---|
| 重复规则 | `AppSettingsTile`（subtitle 动态）+ 行下 `SegmentedButton<RepeatMode>` | `Icons.repeat` | 单次 → `只在今天生成一次`；每日 → `每天凌晨自动生成当天任务`；每周 → `只在选中的星期生成` | 3 段：`单次` / `每日` / `每周`；**初始值 = `appSettings.defaultRepeatMode`**（§2.2 #2 的真实落点） |
| 每周选日 | `Wrap(spacing: AppDimens.sectionHeaderGap, runSpacing: AppDimens.sectionHeaderGap)` 内 7 个 `FilterChip`：`一 二 三 四 五 六 日` | — | 仅 `repeatMode == weekly` 显示 | 选中项 `selected: true`；**一个都没选 → 保存禁用** + 红字 `每周重复至少要选一天`（`AppColors.danger`，`bodySmall`） |
| 规则摘要 | 纯文本（`bodySmall` + `onSurfaceVariant`） | — | 动态生成：`每天生成一次` / `每周一、三、五生成` / `仅 10 月 18 日生成一次` | 无 |

> 摘要行是给用户"复述一遍他的选择"，比禁用一个按钮更能防错。

**组三 · 提醒**

| 字段 | 组件 | 图标 | 文案 | 规则 |
|---|---|---|---|---|
| 设置闹钟 | `AppSwitchTile` | `Icons.alarm` | 开 → `保存后 ${hh:mm} 提醒（${repeatLabel}）`；关 → `只在今日列表出现，不会响铃` | 默认**关**；开启后露出下一行 |
| 提醒时刻 | `AppActionTile`（`trailing: Text(hh:mm, color: active)`） | `Icons.schedule` | `${hh:mm} · ${repeatLabel}` | `showTimePicker`，默认 `07:00`；改动后 SnackBar 不需要（页面内即时反映） |

> 铃音/音量/贪睡**不在本页出现**：它们走 §2.3 的全局默认值，保存时一并写入。避免同一个参数在三个地方可改。

### 5.4 保存流程（伪代码，实现照此）

```dart
Future<void> _save() async {
  final repo = ref.read(taskRepositoryProvider);
  final settings = ref.read(appSettingsProvider);

  final id = await repo.addTemplate(
    type: _type,
    title: _title.trim(),
    repeatMode: _repeat,
    repeatDays: _repeat == RepeatMode.weekly ? (_days.toList()..sort()) : const [],
  );
  await repo.backfill(DateTime.now());        // 列表立即可见

  if (_alarmOn) {
    await ref.read(alarmRepositoryProvider).scheduleForTask(
      taskId: id,
      hour: _time.hour, minute: _time.minute,
      repeatRule: _repeat.name,                // once / daily / weekly
      weekdays: _repeat == RepeatMode.weekly ? (_days.toList()..sort()) : const [],
      scheduledDate: _repeat == RepeatMode.once ? DateTime.now() : null,
      ringtone: settings.ringtone,             // ← §2.3 #6 的真实生效点
      volume: settings.volume,                 // ← §2.3 #7
      snoozeEnabled: settings.snoozeEnabled,   // ← §2.3 #5
      snoozeMinutes: settings.snoozeMinutes,   // ← §2.3 #5b
    );
  }
  if (!mounted) return;
  context.pop();
  ScaffoldMessenger.of(context)..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(_alarmOn ? '任务已创建，闹钟已设为 ${hh:mm}' : '任务已创建')));
}
```

`_canSave` 的真值表（按钮 disabled 时下方必须显示对应提示，禁止无声禁用）：

| 条件 | 按钮 | 提示文案（按钮下方，`bodySmall`，`danger` 色） |
|---|---|---|
| 标题为空 | 禁用 | `请先填写任务标题` |
| 每周但未选日 | 禁用 | `每周重复至少要选一天` |
| 其他 | 可用 | 无 |

### 5.5 放弃确认

`leading` 的 `Icons.close` 与系统返回键，在「标题已输入 / 改过任何选项」时弹：

> 标题 `放弃创建？` 正文 `已填写的内容不会保存。` 按钮 `继续填写` / `放弃`（danger）

---

## 6. 色彩与状态映射表

### 6.1 唯一真源

| 语义 | 常量 | 值 | 用在哪 |
|---|---|---|---|
| 未完成 / 中性 | `AppColors.todo` | `#9CA3AF` | 任务未完成图标、`alarm == null` 的灰、禁用图标 |
| 进行中 / 激活 | `AppColors.active` | `#2563EB` | 计时中图标与标题、主题种子色、区块标题 |
| 成功 / 已开启 / 已授权 | `AppColors.success` | `#10B981` | 开关开启态、精确闹钟已授权、已完成、已设闹钟标志 |
| 警告 / 未授权 / 未完成态提醒 | `AppColors.warning` | `#F59E0B` | 精确闹钟未授权、插件"开发中"图标底色 |
| 错误 / 破坏性 | `AppColors.danger` | `#EF4444` | 删除确认按钮、表单校验红字、每日热量插件主色 |
| 禁用 | `theme.disabledColor` | 主题派生 | `AppDisabledTile` 的文字与图标 |

### 6.2 状态 → 表现 对照

| 业务状态 | 颜色 | 附带符号 | 出现在哪 |
|---|---|---|---|
| 提醒开关已开启 | success | `Switch` 打开 | 设置页 #3 |
| 提醒开关已关闭 | `onSurfaceVariant`（**不是灰掉整行**，因为它仍可点） | `Switch` 关闭 | 设置页 #3 |
| 精确闹钟已授权 | success | `Icons.check_circle` | 设置页 #4 |
| 精确闹钟未授权 | warning | `Icons.warning_amber_rounded` + `去开启` | 设置页 #4 |
| 系统状态读不到 | todo | `Icons.help_outline` + 可点重试 | 设置页 #4 |
| 未实现功能 | disabledColor | `Chip('未开放')` | 设置页 #8/#11/#12/#15/#16 |
| 插件开发中 | disabledColor | `Chip('开发中')` | 工具箱 3 张卡 |
| 任务未完成 | todo | 描边圆圈图标 | 任务卡 |
| 任务进行中 | active | 实心播放图标 + 蓝标题 + `计时中` | 任务卡 |
| 任务已完成 | success | 实心勾 + 删除线 + 灰标题 | 任务卡 |
| 删除/危险动作 | danger | — | 确认框按钮 |

### 6.3 禁止写法（自检 grep 必须为空）

```bash
# 魔法色值
grep -rn "Color(0x" lib/features
grep -rnE "Colors\.(red|green|blue|grey|orange|amber|black|white)" lib/features

# 假控件
grep -rn "onChanged: (_) {}" lib/
grep -rn "onChanged: (v) {}" lib/
grep -rn "onPressed: () {}" lib/
grep -rn "value: true," lib/features/settings        # 逐个人工确认为非常量路由/状态

# 魔法数字（间距 / 字号 / 圆角）
grep -rn "fontSize: [0-9]" lib/features
grep -rnE "SizedBox\((height|width): [0-9]" lib/features
grep -rnE "EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*[0-9]" lib/features
grep -rn "BorderRadius.circular([0-9]" lib/features
```

> 例外：`ui_kit.dart` 内部的 32 / 18 / 9 / 0.12 / 0.8 是组件自身实现值，属既成事实，页面层不得复制这些字面量。

---

## 7. 一致性清单（D7）

### 7.1 间距刻度（只允许这 5 档）

| 值 | 引用 | 典型用途 |
|---|---|---|
| 4 | `AppDimens.cardPadding` | 标题与副标题之间、行内微间距 |
| 8 | `AppDimens.sectionHeaderGap` | chip 之间、图标与文字、标题与卡片 |
| 12 | `AppDimens.cardGap` | 卡片之间、卡片内边距 |
| 16 | `AppDimens.pagePadding` | 页面左右边距 |
| 20 | `AppDimens.sectionGap` | 大区块之间（工具箱卡片组与底部说明） |

> `AppDimens.sectionHeaderGap` 在本规范里**同时承担「8dp 刻度」的角色**（它原义是标题与卡片间距，值同为 8）。若实现者认为语义不贴，P2 可给 `AppDimens` 加 `gap8 / gap4` 两个别名（值不变，零风险），但**不允许**直接写 `8`。

### 7.2 字号白名单（只用 `Theme.textTheme`）

| Token | 用于 |
|---|---|
| `titleSmall` | `AppSectionHeader` 标题（组件内部已定） |
| `titleMedium` | 插件卡标题、空状态标题 |
| `bodyLarge` | 任务卡标题（`ListTile` 默认即 `bodyLarge`） |
| `bodyMedium` | 对话框正文、表单正文 |
| `bodySmall` | 所有 subtitle、说明文字、规则摘要 |
| `labelSmall` | chip 文本 |

**禁止**：`fontSize:`、`TextStyle(fontFamily:)`、自定义 `FontWeight` 超重值（只允许 `w500`/`w600` 用于强调）。

### 7.3 圆角 / 描边 / 图标尺寸

| 项 | 唯一取值 |
|---|---|
| 卡片圆角 | `AppDimens.cardRadius`（12） |
| 图标方块（设置行左侧） | 32×32 / 圆角 12 / 底色 `color.withValues(alpha: 0.12)` / 图标 18 |
| 图标方块（任务卡、插件卡） | 32×32（任务）/ 44×44（插件）/ 圆角 12 / 图标 18（任务）/ 22（插件） |
| 卡片描边 | `Border.all(color: outlineVariant, width: 0.8)`（与 `AppCard` 一致） |
| 点击热区 | ≥ `AppDimens.minTapSize`（44）；`IconButton` 默认 48 已满足，**不要**用 `constraints` 把它压小 |
| 分隔线 | 仅 `AppCard.group` 内部自动插入；页面层不再手写 `Divider` |

### 7.4 反馈（D6）统一写法

```dart
ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()          // 连续点开关时不排队
  ..showSnackBar(SnackBar(content: Text('...')));
```

必须给 SnackBar 的操作：提醒总开关、清理已完成、新建任务、删除任务、保存闹钟。
**不需要** SnackBar 的操作：主题切换、下拉选择、滑块（界面已即时反映，再加提示是噪声）。

---

## 8. 与验收标准 / 现有组件的冲突（如实列出，各给两方案）

### C1（**阻断级**）`ReminderSwitch` 引用了不存在的类，当前无法编译

`lib/features/settings/providers/reminder_switch.dart:44,51` 调用 `AlarmChannel.cancel(...)` / `AlarmChannel.rescheduleAll()`，但 `lib/core/platform/alarm_channel.dart` 里只有 `class AlarmScheduler`（全部 `lib/` 下 grep `class AlarmChannel` = 0 命中）。

| 方案 | 做法 | 代价 |
|---|---|---|
| **A（推荐）** | 把两处改成 `AlarmScheduler.cancel(...)` / `AlarmScheduler.rescheduleAll()` | 2 行；与 `alarm_editor.dart:118` 的用法一致 |
| B | 在 `alarm_channel.dart` 追加 `abstract final class AlarmChannel { static cancel = AlarmScheduler.cancel; ... }` 别名 | 多一层无意义间接，且未来两套名字并存 |

> 这是设置页 P0 项 #3 的前置条件，**必须先修**，否则全包编译失败，UI 无从验收。

### C2 铃音存在两套互不兼容的真源

| 位置 | 内容 |
|---|---|
| `app_settings.dart:33` | `kRingtones = ['风铃轻响', '晨光微露', '静水流深']`（**名字**） |
| `alarm_editor.dart:9-13` | `kBuiltinRingtones = [(id:'default',label:'轻柔钢琴（默认）'), (id:'gentle_bell',label:'风铃轻响'), (id:'soft_wind',label:'林间微风')]`（**id + label**） |

闹钟表存的是 id（`scheduled_alarms.ringtone`），而设置页会存名字 —— 直接接入必然出现「设置里选风铃轻响，闹钟却响默认钢琴」。

| 方案 | 做法 | 代价 |
|---|---|---|
| **A（推荐）** | 以 id 为唯一真源：`AppSettings.ringtone` 存 `id`；把 `alarm_editor.dart` 的 `kBuiltinRingtones` 提为共享常量（如 `lib/core/constants/ringtones.dart`），设置页下拉用 `label` 显示、存 `id`；读取旧值时把中文名映射回 id，映射不到回 `'default'` | 改 3 个文件；需一次性迁移旧 JSON |
| B | 设置页**不提供**「默认铃音」行，改 `AppDisabledTile(reason: '后续迭代开放：统一铃音资源后开放')` | 少一个真实控件，但零风险、零迁移 |

> 若本轮时间紧，选 B 并删掉 §2.3 #6；**绝不能**保留一个"存了名字但没人读"的假设置。

### C3 音量滑块的下限

`volume = 0` 时原生侧行为未经确认（是静音、还是仍以最小音量响）。用户预期"0% = 不响"，若实际仍响，就是信任崩塌。

| 方案 | 做法 |
|---|---|
| **A（推荐）** | `min: 10`，subtitle 写明 `新建闹钟默认音量 ${v}%`；不提供"完全静音"选项（要静音请关总开关） |
| B | 允许 0，并在副标题注明 `0% 时仅震动` —— 需原生侧先确认支持震动替代，未确认前不可用 |

### C4 D4「未完成=灰色」与可读性冲突

| 方案 | 做法 | 问题 |
|---|---|---|
| **A（推荐）** | 状态色只作用于**状态图标 + 状态标签**，标题正文用 `onSurface`；已完成才降为 `onSurfaceVariant` + 删除线 | 严格看"未完成标题不是灰的"，但状态仍由灰色描边图标编码，D4 的意图（一眼分辨）达成 |
| B | 严格按字面：todo 标题也用 `AppColors.todo` | 白底对比度约 2.8:1，低于 WCAG AA 4.5:1，长标题阅读吃力，且"整页灰字"恰恰是"不舒服"的来源 |

> 选 A，并在 E2 自检表「状态有颜色」一栏注明「未完成由灰色描边图标编码，正文不降灰」。

### C5 工具箱"开发中"标签没有现成组件

`AppDisabledTile` 内部私有 `Chip('未开放')`，工具箱卡片需要同样外观的 `开发中` chip，但 `ui_kit.dart` 没有导出 chip 组件。

| 方案 | 做法 | 代价 |
|---|---|---|
| **A（推荐）** | `toolbox_page.dart` 内私有 `_DevChip`，样式逐字段复制 `AppDisabledTile`（`fontSize` 由 `labelSmall` 提供、`surfaceContainerHighest` 底、`outlineVariant` 边、`VisualDensity.compact`） | 一处样式重复，D7 略打折扣 |
| B | `ui_kit.dart` 新增 `AppTagChip(label, {tone})`，`AppDisabledTile` 与工具箱共用 | 更符合 D7，但要改 team-lead 已交付的组件文件 |

### C6 `EmptyState` 不支持行动按钮，R3 的"错误态重试"无处安放

| 方案 | 做法 | 代价 |
|---|---|---|
| **A（推荐）** | 给 `EmptyState` 增加可选 `Widget? action`（`if (action != null) ...`，现有调用不受影响），任务列表错误态传 `TextButton.icon(Icons.refresh, '重试')` | 改共享组件 6 行，向后兼容 |
| B | 错误态不用 `EmptyState`，直接 `Column(mainAxisSize: min, [EmptyState(...), OutlinedButton('重试')])` | 零侵入，但 EmptyState 自带 `Center` + `padding 32`，嵌在 Column 里会出现双倍留白，需再调 |

### C7 文档双源

`docs/ui_design_spec.md`（旧简版）与本文件并存，实现者可能照旧版做，重演"两套规范"。

| 方案 | 做法 |
|---|---|
| **A（推荐）** | 由 team-lead 删除旧文件，或在其首行加 `> 已废弃，实现依据见 docs/ui-design-spec.md` |
| B | 保留旧文件作为历史记录，但两份都在 `docs/` 下，风险是有人读错 |

> 我不删除他人文件，此项需 team-lead 决定。

---

### C8（与既有实现任务冲突）「右侧闹钟 + 完成 + 删除」三按钮

任务卡 #2 的原始描述是「右侧闹钟+完成+删除按钮（完成在 done 时 `onPressed: null` 并灰化）」，这与 §4.5 直接冲突，必须二选一，否则实现者会照旧描述做出 §4.1 P1 的问题。

| 方案 | 做法 | 结果 |
|---|---|---|
| **A（推荐）** | 完成 + 更多（⋮ 弹出「设置/编辑闹钟」「删除」） | 标题可用 **148dp**（约 7 汉字不换行）；删除与完成不在同一排，误触风险消除；done 行只剩 ⋮ |
| B | 保留三按钮，改 `visualDensity: compact` + leading 缩到 32 + 标题 `maxLines: 1` | 标题约 120dp（6 汉字即截断），完成与删除间距仍为 0，误触问题一个都没解决 |

另有两处**不随方案变**的硬要求：

1. **done 行不要「灰化的完成按钮」**。任务已完成，"完成"动作没有意义；而灰色在 §6 的语义里等于「禁用/不可用」，与「已完成」冲突（已完成应为 `success` 绿，且已由左侧实心勾 + 删除线表达）。**隐藏**它。
2. **「整卡 InkWell 水波纹」在 done 行必须 `onTap: null`**。有水波却什么都没发生，就是 R1 点名的假控件。

> 若 team-lead 坚持三按钮方案（B），需在 E2 自检表里如实注明「标题在窄屏会截断」，并接受评审方按 D2/D7 提出异议。

---

## 9. 交付自查表（实现完成后填，对应 E2）

| 页面 | 有卡片分组 | 每行有图标 | 每行有说明 | 状态有颜色 | 有假控件 | 三态齐全 | 截图 |
|---|---|---|---|---|---|---|---|
| 设置 | 4 个区块 × 卡片 | 全部是（组件强制） | 全部是（组件强制，4 行随状态变） | #3/#4/#8 有 | 无（11 个控件见 §2.6） | 行级：#4 三态 + #9 加载态 | settings.png |
| 工具箱 | 3 张卡（非 ListTile） | 是（44×44） | 是（价值 + 规划 + 开发中） | 3 个 `开发中` chip | 无（卡片不可点） | 无异步数据 → 不适用 | toolbox.png |
| 任务列表 | 一任务一卡 | 是（40dp 状态列） | 是（类型 + 闹钟 + 计时） | 三态完整 | 无（完成/更多都可点） | 是（含重试） | task_list.png |
| 新建任务 | 3 组卡片 | 是 | 是（含动态规则摘要） | 校验红字 + 蓝标题 | 无（禁用按钮带原因） | 表单无空态 → 不适用 | add_task.png |

**E3 假控件自查**：直接复用 §2.6 表 + 任务卡的「完成 / 更多 → 编辑闹钟 / 删除」+ 新建任务的「保存 / 类型 / 重复 / 选日 / 闹钟开关 / 时间」，每项都必须能写出一句"点击后发生什么"。

**E4 占位说明**：工具箱 3 张卡 + 设置页 5 行 disabled 项，截图需能看清 `开发中` / `未开放` 标签。

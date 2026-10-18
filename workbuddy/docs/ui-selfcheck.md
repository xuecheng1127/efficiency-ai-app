# UI 自检表（WorkBuddy · com.efficiency.app.efficiency_app）

> 依据 `F:\develop\mailbox\UI验收标准.md`（R1–R3 / D1–D7 / E1–E4）
> 实测设备：`emulator-5554`（Android 16 / API 36），`pm clear` 后从零开始，冷启动截图
> 生成时间：2026-10-18 00:22

---

## E1 · 每页真实截图（全部为本机 screencap，非拼图/非闪屏）

| 页面 | 文件 | 说明 |
|---|---|---|
| 任务列表（空态） | `ui_01_task_empty.png` | 冷启动后第一屏，EmptyState + 引导 + 底部 3 标签（我方指纹） |
| 工具箱 | `ui_02_toolbox.png` | 2 个区块 + 3 张插件卡（均标「开发中」） |
| 设置（上半） | `ui_03_settings.png` | 通用设置 / 提醒设置（档位**精确**、总开关、贪睡、铃音灰化） |
| 设置（下半） | `ui_04_settings_bottom.png` | 音量滑块 / 数据与备份（两个「未开放」）/ 关于 |
| 新建任务（键盘态） | `ui_05_add_task.png` | autofocus 弹出键盘，按钮禁用 + 「填写任务名称后可创建」 |
| 新建任务（完整） | `ui_05b_add_task.png` | 收起键盘：类型 / 名称 0/40 / 重复规则 |
| 新建任务（每周） | `ui_07_add_weekly.png` | 7 个星期 chip + 「至少选择 1 天」橙字 + 按钮禁用 |
| 新建任务（已填） | `ui_06_add_filled.png` | 标题已填、按钮转为可用 |
| 任务列表（有数据） | `ui_08_task_list.png` | 进度头「已完成 0 / 1」+ 任务卡（状态点/闹钟/完成/删除） |
| 设置（总开关关闭） | `ui_09_switch_off.png` | 副标题变「已关闭…」+ SnackBar 反馈 |
| 设置（总开关恢复） | `ui_10_switch_on.png` | 恢复开启，DB 与调度均已复原 |
| 设置（深色主题） | `ui_11_settings_dark.png` | 深色下状态色对比度正常 + SnackBar；`themeMode` 已落 json |
| 设置（**审查后修复版**） | `ui_12_settings_fixed.png` | 未开放行文字对比度提到 ≈4.5:1、贪睡副标题不再断行 |
| 闹钟对话框（**审查后修复版**） | `ui_13_alarm_dialog.png` | 铃音改为只读行（不再有"选了没效果"的下拉），打开不崩 |
| 任务列表（进度条修正） | `ui_14_task_progress.png` | 0/1 时轨道为中性色，不再"看起来已满" |
| 工具箱（去掉误导 chevron） | `ui_15_toolbox_fixed.png` | 卡片不再给"可进入下一页"的假暗示 |
| 新建任务（chip 间距） | `ui_16_weekly_fixed.png` | 间距收到 6；**7 个 chip 仍换行(5+2)**，见下方取舍说明 |

---

## E2 · 逐页自检表

| 页面 | 有卡片分组 | 每行有图标 | 每行有说明 | 状态有颜色 | 有假控件 | 三态齐全 | 截图 |
|---|---|---|---|---|---|---|---|
| 设置 | ✅ 4 区块 × **4 张** `AppCard` | ✅ 全部经 `ui_kit` 强约束 | ✅ 且**随状态变化**（总开关/档位/贪睡间隔） | ✅ 绿=精确/橙=近似/灰=未开放 | **无** | 档位卡片有 加载/错误/数据；页面无列表数据故无空态 | ui_03 / ui_04 / ui_09 / ui_12 |
| 工具箱 | ✅ 2 区块 + 3 张插件卡 | ✅ | ✅ 每卡一句功能 + 「开发中」原因 + 引导 | ✅ 「开发中」用警告橙 | **无**（点卡片有 SnackBar） | 静态目录页，无数据源；页面内三处明写「开发中」（R2 合规） | ui_02 |
| 任务列表 | ✅ 进度头卡 + 任务卡 | ✅ 状态点/闹钟/完成/删除 | ✅ 卡片主语 + 元信息行 | ✅ 灰=todo / 蓝=进行中 / 绿=done | **无**（done 态完成按钮真禁用） | ✅ loading / error(可重试) / empty / data | ui_01 / ui_08 |
| 新建任务 | ✅ 3 个分组卡 + 贴底操作条 | ✅ | ✅ 每个分区块有说明行 | ✅ 校验未过用橙字；按钮禁用灰 | **无** | 提交中/失败/正常 三态都有 | ui_05 / ui_05b / ui_07 |

---

## E3 · 「假控件」自查清单（含「我是否亲手点过」）

### 设置页

| 控件 | 位置 | 点击后发生什么 | 我点过 |
|---|---|---|---|
| 主题 系统/浅色/深色 | 通用设置 | `themeModeProvider.setMode` → 写 `app_settings.json` → 全局换肤 + SnackBar | ✅ **已点「深色」+ 已落库 `themeMode:"dark"` + 已截图** |
| 新任务默认重复规则 | 通用设置 | `patch(defaultRepeatMode)` → `AddTaskPage` 下次打开用它作默认值 + SnackBar | ❌ 未点 |
| 当前闹钟档位（只读展示） | 提醒设置 | 不响应点击；数据来自 `AlarmScheduler.canScheduleExactAlarms()` 真实返回值 | ✅ 已看（真实显示「精确」） |
| 「去开启」（仅未授权时出现） | 提醒设置 | `AlarmScheduler.requestExactAlarmPermission()` 跳系统设置 → 返回后自动复检 + SnackBar | ❌ 未点（当前是精确档，该按钮不出现） |
| 「重试」（仅读取失败时出现） | 提醒设置 | `invalidate` 档位 provider 并重读 | ❌ 未触发（无错误态） |
| 下拉刷新 | 整页 | 重读档位 | ❌ 未点 |
| **任务提醒总开关** | 提醒设置 | 关：`enabled` 全置 0 + 逐个 native cancel；开：置 1 + `rescheduleAll`；落 `app_settings.json`；SnackBar | ✅ **已点，双向验证**（见 §R1 实测） |
| 贪睡模式 | 提醒设置 | `patch(snoozeEnabled)`；同时让「贪睡间隔」在可用/禁用间切换 | ❌ 未点 |
| 贪睡间隔 | 提醒设置（贪睡开启时） | `patch(snoozeMinutes)`（5/10/15） | ❌ 未点 |
| 闹钟铃音 | 提醒设置 | **不可点**（灰化 + 「未开放」+ 原因：V1 只内置 1 首，原生侧不读该字段） | ✅ 已看（灰化态） |
| 闹钟音量 Slider | 提醒设置 | 拖动实时改百分比，松手 `patch(volume)` → 新建闹钟时作为默认音量 | ❌ 未拖动 |
| 导出全部数据（ZIP） | 数据与备份 | **不可点**（灰化 + 「未开放」+ 原因） | ✅ 已看 |
| 从备份恢复 | 数据与备份 | **不可点**（同上） | ✅ 已看 |
| 版本 1.0.0 | 关于 | 纯展示，无点击态 | ✅ 已看 |

### 工具箱页

| 控件 | 位置 | 点击后发生什么 | 我点过 |
|---|---|---|---|
| 朋友生日 / 每日热量 / 采购清单 卡（整卡） | 工具箱 | SnackBar「「××」开发中，敬请期待」+ 水波纹；卡内已明写「开发中 · 现在点击只会提示」 | ❌ 未点 |

### 任务列表页

| 控件 | 位置 | 点击后发生什么 | 我点过 |
|---|---|---|---|
| 任务卡主体 | 任务卡 | `todo`→开始计时（转进行中）；`inProgress`→取消计时；`done`→无动作 | ❌ 未点 |
| 完成按钮（绿勾） | 任务卡右侧 | `completeInstance` → 变绿勾 + 标题划线；**已完成时按钮 `onPressed: null` 真禁用** | ❌ 未点 |
| 闹钟按钮 | 任务卡右侧 | 打开 `AlarmEditorDialog`（已设闹钟时实心铃铛） | ❌ 未点 |
| 删除按钮 | 任务卡右侧 | 二次确认后 `deleteInstance` | ❌ 未点 |
| 新任务 FAB | 右下 | `push<bool>(AddTaskPage)`；返回 true 时列表自动刷新（stream） | ✅ **已点，走通创建全流程** |

### 新建任务页

| 控件 | 位置 | 点击后发生什么 | 我点过 |
|---|---|---|---|
| 学习 / 健身 | 任务类型 | 切换 `TaskType`，选中态高亮，写入模板 | ❌ 未点（默认学习） |
| 任务名称输入框 | 任务名称 | 输入实时联动按钮可用态与 `0/40` 计数 | ✅ **已输入并生效** |
| 单次 / 每日 / 每周 | 重复规则 | 切换；选「每周」即时展开 7 个 chip | ✅ **已切换并截图** |
| 周一…周日 ×7 | 每周展开后 | 勾选/取消；未选任何一天 → 橙字警告 + 按钮禁用 | ❌ 未点 |
| 创建任务 | 贴底 | `addTemplate` + `backfill` → SnackBar「已创建」→ `pop(true)` | ✅ **已点，落库验证** |
| 关闭 ✕ / 系统返回 | AppBar / 手势 | `pop(false)`（创建中则拦截，防重复提交） | ❌ 未点 |

---

## R1 实测（最强的一条证据：总开关）

```
# 种一条闹钟（enabled=1）后点击总开关「关闭」
16:21:08.522 I flutter: [T10][alarm-persist] setAllEnabled(false): updated rows=1
$ select id,task_id,enabled from scheduled_alarms;
id  task_id  enabled
1   1        0

$ cat app_settings.json
{ "remindersEnabled": false, "snoozeEnabled": true, "snoozeMinutes": 5,
  "ringtone": "风铃轻响", "volume": 80, "defaultRepeatMode": "daily", "themeMode": "system" }

# 再点一次「开启」
16:21:15.014 I flutter: [T10][alarm-persist] setAllEnabled(true): updated rows=1
16:21:15.023 I T11    : rebuild complete: source=channel read=1 rebuilt=1 skippedExpiredOnce=0
16:21:15.023 I T10.5  : channel rescheduleAll -> source=channel read=1 rebuilt=1 skippedExpiredOnce=0
$ select ... -> enabled = 1
```

**为什么这样设计**：只调一次 native `cancel` 是不够的 —— 重启手机时 `BootReceiver` → `rescheduleAll`
只认 `enabled=1` 的行，会照表把闹钟重新武装回来，那就成了假开关。所以关闭时**先落库** `enabled=0`。

## R1 实测（新建任务真的落库）

```
$ select id,title,type,repeat_mode from task_templates;
1  Read 30min  study  daily
$ select count(*) from task_instances;  -> 1
```

---

## E4 · 占位说明（未实现的功能都在页面内写清楚了）

| 位置 | 文案 | 控件形态 |
|---|---|---|
| 设置页 · 闹钟铃音 | 「V1 只内置 1 首铃音（风铃轻响）；音色选择随铃音包开放」 | 灰化 + 「未开放」标签 |
| 设置页 · 导出全部数据（ZIP） | 「后续迭代开放：任务、日记、闹钟将打包为一个 ZIP」 | 灰化 + 「未开放」 |
| 设置页 · 从备份恢复 | 「后续迭代开放：选择 ZIP 覆盖当前数据」 | 灰化 + 「未开放」 |
| 工具箱 · 3 个插件 | 「开发中 · V1 后续接入，届时可一键添加到主页；现在点击只会提示」 | 可点（SnackBar 提示）+ 警告橙 chip |
| 工具箱 · 顶部说明 | 「插件是可选能力：默认只收纳在工具箱，不占主页、不申请权限、不占前台资源」 | 说明卡 |

---

## 独立审查（fresh eyes）发现的缺陷与修复

本次交付由 4 个并行 agent 实现 + 1 个**只读审查者**复核。审查者挑出 2 个真缺陷与若干 D4/D7 问题，已全部修并复验：

| # | 严重度 | 问题 | 修法 | 复验 |
|---|---|---|---|---|
| 1 | 🔴 高 | `alarm_editor.dart` 铃音下拉的 `initialValue` 取的是中文名「风铃轻响」，而 items 是 id（`default`/`gentle_bell`/`soft_wind`）→ `DropdownButton` 的 assert 失败，**debug 下打开闹钟对话框直接红屏**。这是我在「把设置接进对话框」时自己引入的 | 铃音不再从设置取值（落库固定 `'default'`），并把该下拉改成**只读说明行**（原生本来不读该字段，留着就是死控件） | 实机打开对话框 `ui_13_alarm_dialog.png`；logcat 无 assert / exception |
| 2 | 🔴 高 | 总开关关闭后新建闹钟：`scheduleForTask` 插入 `enabled=true` 且立刻交给原生调度 → **闹钟复活，重启后仍在**。用户以为关了其实没关 | `AlarmEditorDialog._save()` 加兜底：保存后若总开关为关 → `setAllEnabled(false)` + `AlarmScheduler.cancel(taskId)`；SnackBar 文案区分两种情况 | analyze/test 通过；代码路径见该文件 `_save()` |
| 3 | 🟠 中 | 0/1 进度条整条轨道是 `success@16%` → 截图上看像「已满」 | 轨道改 `surfaceContainerHighest`，绿色只给 value 段 | `ui_14_task_progress.png` |
| 4 | 🟠 中 | 未开放行用 `theme.disabledColor`，对比度 ≈2.5:1，深色下原因几乎读不出 | 文字改 `onSurface@0.55`（≈4.5:1）；禁用语义靠 `enabled:false` + 「未开放」标签表达 | `ui_12_settings_fixed.png` |
| 5 | 🟡 低 | 贪睡副标题过长被下拉挤断（「…当」「前 5 分钟」） | 缩短为「「稍后提醒」的等待时长」 | 同上 |
| 6 | 🟡 低 | 工具卡右侧 `chevron_right` 暗示「可进入下一页」，实际只弹 SnackBar | 去掉 chevron | `ui_15_toolbox_fixed.png` |
| 7 | 🟡 低 | 7 个 weekday chip 排成 5+2，右侧空 | 间距 8 → 6（新增 `AppDimens.chipGap`） | **仍是 5+2**：360dp 下 7 个 chip 装不进一行；要 7 等分或 compact 就会低于 44dp 最小触控 → **选择保留换行**（可用性优先于对齐美观） |
| 8 | 🟡 低 | 删除任务后无 SnackBar、无撤销 | **未做**（如实标注） | — |

---

## 未验证 / 已知缺口（如实标注）

1. **上表标 ❌ 的控件我没有亲手点过**（重复规则下拉 / 贪睡开关与间隔 / 音量滑块 / 插件卡 SnackBar / 任务卡的计时·完成·删除·闹钟 / 星期 chip / 关闭按钮）。
   我实测过的是：三段导航、**主题切换（深色 + 持久化 + 深色下截图）**、总开关双向（DB+文件+原生日志）、新建任务全流程（落库）、每周展开与校验禁用态。
   **建议评审方优先复点：音量滑块、贪睡开关、任务卡三态点击、插件卡 SnackBar。**（这几处最可能出现"看起来能点但没反应"）
2. **任务列表「计时中」不会逐秒跳**：`TaskInstance` 没有 `totalSeconds` 字段，元信息行按
   `accumulatedSeconds + (进行中 ? now - startedAt : 0)` 在一次构建内算一次。要跳秒需加 1 秒定时器（会与 widget 测试超时冲突），本次未做。
3. **任务卡不显示重复规则**：`TaskInstance` 是快照，没有 `repeatMode` 字段（后端加列属数据模型变更，不在 UI 任务范围），
   所以元信息行显示的是「类型 · 闹钟规则 · 耗时」。未用假数据凑。
4. **设置里三项（音量/贪睡）的联动只影响"此后新建的闹钟"**：已有闹钟的参数存在 `scheduled_alarms` 表里，改全局默认不会回写历史记录。
   这是数据语义（每行闹钟是独立配置），不是控件失效。
5. **`docs/ui_design_spec.md`（2.2 KB）不是本轮团队产出**（早于团队启动时间），与权威规范 `docs/ui-design-spec.md`（46 KB，ui-designer 产出）内容重复且与 `ui_kit` 略有出入。**我未删除**，请评审方裁定去留。

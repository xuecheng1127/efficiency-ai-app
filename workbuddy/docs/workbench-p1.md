# 自定义工作台（模块4 · P1）

> 目标：**主页显示什么，由用户决定**。
> 范围：P1「选择显示哪几个模块」——不做拖拉拽布局、不做无限分区、不做表格模式。

## 1. 需求 → 实现 对照

| 要求 | 实现 | 证据 |
|---|---|---|
| ① 至少给个工作台 tab 或入口 | 底部导航从 3 格变 **4 格**：`工作台 / 任务 / 工具箱 / 设置`，工作台是第 1 格（启动即落地） | `wb_01_empty.png` 底部四个 tab |
| ② 用户能配置主页显示什么 | 配置页两个开关（今日任务 / 日记）+ 3 个预设；工作台按配置渲染模块卡片 | `wb_04_config_set.png`、`wb_03_configured.png` |
| ③ 配置存 SharedPreferences 或 settings 表 | 存进已有的 `app_settings.json`（`SettingsStore`），键 `workbenchModules: ["tasks","diary"]` | 设备上 `cat app_settings.json` 实测输出（见 §4） |
| ④ 空态「还没配置」+ 2–3 个预设 | 空态标题「工作台还没配置」+ 3 个预设（只看任务 / 只看日记 / 任务 + 日记）+「手动选择模块」 | `wb_01_empty.png` |

**验收截图**：空态 `docs/shots/wb_01_empty.png`、配置页 `wb_02_config_unset.png` / `wb_04_config_set.png`、配置后主页 `wb_03_configured.png` / `wb_07_persisted.png`。

## 2. 为什么保留独立的「任务」tab

工作台是**可配置的组合视图**（卡片预览 + 进模块），任务页是**完整功能页**（新建、计时、完成、删除、闹钟）。
把任务塞进工作台只有两个结果：要么牺牲功能，要么在工作台里再写一份任务列表 —— 后者违反「同一份数据只有一套 UI 逻辑」。

所以：工作台的模块卡片**只读、只预览 + 一个「查看全部 / 去创建」入口**，
所有写操作仍然发生在模块自己的页面里。

## 3. 代码结构

| 文件 | 作用 |
|---|---|
| `lib/features/workbench/domain/workbench_module.dart` | **纯 Dart**：模块枚举（稳定 id `tasks`/`diary`）、预设、容错解析（去重 / 丢未知 id / 保序） |
| `lib/features/workbench/providers/workbench_providers.dart` | 读配置（`workbenchModulesProvider`）、写配置（`WorkbenchConfig`：`applyPreset` / `toggle` / `setModules` / `reset`） |
| `lib/features/workbench/presentation/workbench_page.dart` | 工作台页：空态 + 预设 / 模块卡片（任务、日记） |
| `lib/features/workbench/presentation/workbench_config_page.dart` | 配置页：模块开关、预设、恢复未配置 |
| `lib/features/workbench/presentation/workbench_icons.dart` | 模块图标（表现层，避免页面互相 import 形成环） |
| `lib/features/home/presentation/home_page.dart` | 底部导航 3 → 4 格 |
| `lib/core/settings/app_settings.dart` | 新增 `workbenchModules` 字段（含容错解析） |
| `lib/core/widgets/ui_kit.dart` | 新增公开组件 `AppModuleIcon`（卡片头 32dp 图标底板），避免各页复制尺寸 |
| `test/features/workbench/workbench_module_test.dart` | 13 条纯逻辑断言（顺序 / 未知 id / 重复 / 空=未配置 / 预设命中 / JSON 往返与坏数据） |

## 4. 数据存储与容错

```json
{
  "remindersEnabled": true,
  "themeMode": "light",
  "workbenchModules": ["tasks", "diary"]
}
```

- **空列表 = 还没配置** → 工作台显示空态；不是「配置成什么都不显示」。
- 顺序即渲染顺序（用户自定义组合按选择顺序排）。
- `AppSettings._parseStringList` 只收 `String`：混进数字 / null 会被跳过，整个字段类型不对则退回空列表；
  未知 id 在 `parseWorkbenchModules` 里被丢掉。**坏配置等价于未配置，绝不让应用崩**。

## 5. 假控件自查表

| 控件 | 位置 | 点击后发生什么 |
|---|---|---|
| 预设卡 ×3 | 空态 | `applyPreset` → 写 `app_settings.json` → 工作台立即渲染对应模块 + SnackBar「已应用预设：…」 |
| 「手动选择模块」 | 空态底部 | push 配置页 |
| 右上角「配置工作台」 | 工作台 AppBar | push 配置页 |
| 「今日任务」开关 | 配置页 | `toggle(tasks)` → 落盘 + SnackBar「已显示/已隐藏「今日任务」」→ 返回工作台生效 |
| 「日记」开关 | 配置页 | 同上 |
| 预设行 ×3 | 配置页 | `applyPreset` → 落盘 + SnackBar；当前命中项右侧显示绿色 ✓ |
| 「恢复到未配置」 | 配置页 | 确认框 → `reset()` → 空列表 → 工作台回到空态 |
| 「查看全部 / 去创建」 | 任务卡 | push 任务页（真的能进） |
| 「打开 / 写一篇」 | 日记卡 | push 日记页（真的能进） |
| 任务预览行 / 日记摘要 | 卡片内 | **不可点击**（纯文本，没有设 InkWell）——预览不假装能操作 |

没有「点了没反应」的控件；配置页**刻意没有「保存」按钮**（一拨就落盘），否则忘了点就会变成假控件。

## 6. 实测证据（emulator-5554）

```
# 1) 预设「任务 + 日记」后，设备上的设置文件
"workbenchModules": ["tasks", "diary"]

# 2) 配置页关掉「日记」
"workbenchModules": ["tasks"]          → 工作台只剩任务卡（wb_06_tasks_only.png）

# 3) 配置页重选「任务 + 日记」并强制重启应用
"workbenchModules": ["tasks", "diary"] → 工作台仍是两张卡（wb_07_persisted.png，冷启动 COLD）
```

- `dart analyze`：**0 error / 17 info**（与改动前逐条一致，新文件 0 条）
- `flutter test`：**166 / 166 通过**（含新增 13 条工作台断言）
- 设备：只用了 `emulator-5554`（`acquire → guard → release`），**未触碰 emulator-5556 与真机**

## 7. 未做 / 边界（如实标注）

1. **P1 不做**：无限分区、分区命名/图标、拖拉拽排序、表格模式、笔记模式。按 README 的 TODO，P2 再上。
2. 模块顺序固定为「任务 → 日记」（按配置的写入顺序）；**没有**排序 UI —— 因为 P1 只有两个模块，排序 UI 的价值低于它带来的误操作成本。
3. 工作台卡片是**预览**：不内嵌「开始计时 / 完成」等写操作（避免与任务页两套状态机）。
4. 日记模块只显示最近一篇（`rows.first`，按日期倒序）；没有「今日日记」强制语义。
5. 演示数据说明：为验证日记模块读真实数据，我在模拟器里写入了一条日记（标题「工作台验收」），
   仅存在于模拟器，不进代码库、不影响其它环境。

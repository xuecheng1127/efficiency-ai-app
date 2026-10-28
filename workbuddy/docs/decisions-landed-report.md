# 定案 → 代码 · 落地校验报告

- 生成时间：2026-10-29 03:49:39
- 入口：`flutter test test/decisions/`（同一份断言也在全量 `flutter test` 里跑）
- 扫描：151 个文件（`android/app/src/main` + `lib` + `test/decisions`；扩展名 .kt/.dart/.xml）

| # | 定案 | 状态 | 这条断言检查什么 |
|---|---|---|---|
| D1 | 禁止无条件 startActivity 拉全屏 | ✅ 已落地 | ① `AlarmReceiver.kt` / `AlarmService.kt` 的**代码**里没有裸 `startActivity(`；② 全工程代码里没有「同一行同时出现 `startActivity(` 与 `AlarmFullScreenActivity`」；③ 正向：全屏入口走 `AlarmNotifications` 的 `setFullScreenIntent(`。 |
| D2 | 禁止 KEYCODE_POWER 拦截 | ✅ 已落地 | `android/app/src/main` + `lib` 的**代码**里不出现 `KEYCODE_POWER`（注释里的说明不算违规；已同时统计原文出现次数并逐条列出，不做隐藏）。 |
| D3 | 参数一律回表读，不走 Intent extra | ✅ 已落地 | ① 正向：`AlarmService.kt` 的代码里存在 DB 读取（`AlarmStore.`）；② 反向：闹钟包内所有 `get*Extra(...)` 的 key 必须落在白名单内（`EXTRA_TASK_ID` + 两个**控制标记**，控制标记不是响铃参数，逐条给了理由）；③ 反向：`AlarmService.kt` 里不出现任何「闹钟参数形态」的 extra 名（`EXTRA_RINGTONE` / `EXTRA_VOLUME` / `EXTRA_TITLE` / `EXTRA_SOUND`）——这条才是 ADR-008 的核心防护。 |
| D4 | 界面如实告知档位 | ✅ 已落地 | `lib/features/alarm/presentation/**` 里**至少有一个**页面：`final x = await AlarmScheduler.canScheduleExactAlarms()`，**且该值在后续条件分支里被使用**（只打日志不算「告知用户」）。范围限定在闹钟相关页面 —— 档位是闹钟的概念，其它页面不需要引用它。 |
| D5 | 前台服务必须声明 foregroundServiceType | ✅ 已落地 | 从 `AndroidManifest.xml` 切出**每一个** `<service>` 块：每块都必须含 `android:foregroundServiceType=`；`AlarmService` 必须是 `specialUse` 且有 `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` 用途说明；并声明 `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE` 两个权限。 |
| D6 | 响铃不得绑在 Activity 生命周期上 | ✅ 已落地 | ① 反向：`AlarmFullScreenActivity.kt` 的代码里没有 `MediaPlayer` / `Vibrator` / `startRing(` / `stopRing(` / `stopRingtone(`（页面只做 UI）；② 正向：`AlarmService.kt` 持有 `MediaPlayer` + 有 `RING OWNER started` 归属日志 + `finishRing`/`stopRingtone` 收尾 + `STOP_FOREGROUND_REMOVE`；③ 反向：`AlarmService.kt` 的代码里不引用 `AlarmFullScreenActivity`（互不依赖）。 |
| D7 | 校验机制自身避开两个已知坑 | ✅ 已落地 | `test/decisions/**` 的代码里：① 不出现异步的 `.exists()`（必须用 `existsSync()`）；② 不出现 `expect(await ...)`（把 Future 交给 expect 就是坑 2）；③ 正向：底座里存在 `existsSync()`。 |

## 未落地条目（0）

无。全部 7 条断言通过。

## 逐条证据

### D1 · 禁止无条件 startActivity 拉全屏

- 依据：PRD v2.2 硬伤 1（后台启动 Activity 受限，10+ 直接抛异常）
- 状态：✅ 已落地
- `AlarmNotifications.kt` 里 `setFullScreenIntent(` 命中 1 处：android/app/src/main/kotlin/com/efficiency/app/efficiency_app/alarm/AlarmNotifications.kt:116
- 全工程代码里 `startActivity(` 共 1 处（android/app/src/main/kotlin/com/efficiency/app/efficiency_app/alarm/AlarmScheduler.kt:82）—— 这些是「用户亲手点『去开启』后打开系统设置页」，与「到点无条件拉起全屏」是两件事；断言①只约束到点路径。

### D2 · 禁止 KEYCODE_POWER 拦截

- 依据：PRD v2.2 硬伤 2（电源键事件不向普通应用分发，拦不到）
- 状态：✅ 已落地
- 代码中命中 0 处（要求 0）
- 原文命中 1 处，其中 1 处位于注释（文档说明，按设计不算违规）：android/app/src/main/kotlin/com/efficiency/app/efficiency_app/alarm/AlarmFullScreenActivity.kt:37

### D3 · 参数一律回表读，不走 Intent extra

- 依据：ADR-008（`scheduled_alarms` 是参数的唯一真源，Intent 只带 taskId）
- 状态：✅ 已落地
- 闹钟包内 `get*Extra(` 读取共 6 处：AlarmFullScreenActivity.kt:57、AlarmFullScreenActivity.kt:133、AlarmReceiver.kt:22、AlarmService.kt:137、AlarmService.kt:167、AlarmService.kt:289（白名单外的即违规）
- `AlarmService.kt` 里 `AlarmStore.` 命中 1 处 —— 响铃参数（标题 / 铃声 / 音量 / 贪睡）全部由 `AlarmStore.loadByTask()` 回表取。

### D4 · 界面如实告知档位

- 依据：PRD v2 §3.3 约束 4（界面必须如实告知当前档位）
- 状态：✅ 已落地
- 读取真实档位：`lib/features/alarm/presentation/alarm_editor.dart:146` → `final exact = await AlarmScheduler.canScheduleExactAlarms();`
- 并在分支中被使用：`lib/features/alarm/presentation/alarm_editor.dart:147`
- ⚠ 只能人工核对：本断言只证明「UI 消费了真实返回值并用于分支」，**不覆盖**「常驻显示当前档位」的界面（那属 T18 的 UI 呈现范围），也不校验文案措辞。人工核对方式：任务列表点铃铛保存 → 若当前是近似档，应弹出「开启闹钟和提醒权限」引导；在系统设置里关掉该权限后重试，引导应再次出现。

### D5 · 前台服务必须声明 foregroundServiceType

- 依据：T17 定案 / ADR-007（API 34+ 未声明类型会启动失败）
- 状态：✅ 已落地
- `<service>` 块共 1 个
- `<service .alarm.AlarmService>` → `specialUse`（第 119 行）
- 权限 `android.permission.FOREGROUND_SERVICE"`（40 行）
- 权限 `android.permission.FOREGROUND_SERVICE_SPECIAL_USE"`（41 行）

### D6 · 响铃不得绑在 Activity 生命周期上

- 依据：T13b 定案（真机实测：Activity 被 ROM 收掉后铃只响 211 毫秒）
- 状态：✅ 已落地
- `AlarmFullScreenActivity.kt` 代码中 `MediaPlayer|Vibrator|stopRing` 命中 0 处（要求 0）
- 服务侧 `MediaPlayer` 命中（AlarmService.kt:8）
- 服务侧 `RING OWNER started 归属日志` 命中（AlarmService.kt:188）
- 服务侧 `finishRing/stopRingtone 收尾` 命中（AlarmService.kt:244）
- 服务侧 `STOP_FOREGROUND_REMOVE` 命中（AlarmService.kt:358）

### D7 · 校验机制自身避开两个已知坑

- 依据：T20 交接提醒：坑 1 `File.exists()` 是 Future；坑 2 `expect(Future, isTrue)` 永远失败
- 状态：✅ 已落地
- 扫描本机制自身 4 个文件
- `test/decisions/decision_support.dart:64` 使用 `existsSync()`（同步，避开坑 1）

## 反向验证（证明断言不是橡皮图章）

见 `test/decisions/decision_mechanism_selftest_test.dart`：
对每条定案注入一处**代表性违规**（如给 `AlarmService` 加一行 `intent.getStringExtra(EXTRA_RINGTONE)`），断言必须变成 ❌ 且报出文件名与行号。
若某条断言是空的，那个反向验证用例会红。

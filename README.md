# 效率助手 · AI 双实现对照

> 同一份 PRD，两个 AI 各自独立实现的安卓效率应用。

[![Platform](https://img.shields.io/badge/Android-10%2B-3DDC84?logo=android)](https://www.android.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter)](https://flutter.dev/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

---

## 这是什么

一个**纯原生、零云端**的安卓效率应用。没有账号、没有网络依赖、没有订阅，所有数据存在本地 SQLite。

**特别之处**：这个项目用同一份 PRD 同时驱动了两个 AI 编码助手（WorkBuddy 和豆包）独立实现，
两份代码库用来对照评估：
- 同一个需求，两个 AI 会做出什么样的不同设计？
- 谁在架构上更稳、谁在工程上更严、谁在 UI 上更好？
- 各自的 bug 模式是什么？

---

## 两个实现

| | WorkBuddy 实现 | 豆包实现 |
|---|---|---|
| **目录** | [`workbuddy/`](workbuddy/) | [`doubao/`](doubao/) |
| **测试** | **153/153** | 37/37 |
| **Dart 代码量** | 29,963 行 / 140 文件 | 16,780 行 / 79 文件 |
| **构建产物** | release APK 58.9 MB | debug APK 192 MB |
| **工具箱** | **5 个插件** | **5 个插件** |
| **工作台** | **自定义（4 tab）** | 占位 |
| **火花/勋章** | ❌ | **✅** |
| **途径提醒** | **✅** | **✅（前台）** |
| **CJK 排版引擎** | **518 行（拆 5 文件）** | 179 行 |

---

## 共同实现的功能

### 任务体系
- 单次 / 每日 / 每周重复
- 三态：未完成 → 计时中 → 已完成
- 精确闹钟 + 贪睡（三档降级）
- 重复任务惰性 backfill
- **误触保护**：完成可撤销 + 已完成可标记回未完成（带确认）

### 日记
- 横线本（CustomPaint 真实画线，间距 = 字号 × 1.5）/ 空白本
- **自动保存三重保护**：定时 + AppLifecycleState + SharedPreferences 草稿兜底
- 强杀重开可恢复未保存内容
- 搜索高亮

### 工具箱（两边都有 5 个）
| 插件 | 豆包 | WorkBuddy |
|---|---|---|
| 备忘录 | ✅ | ✅ |
| 采购清单 | ✅ | ✅ |
| 朋友生日 | ✅ | ✅ |
| 每日热量 | ✅ | ✅ |
| 途径提醒 | ✅ | ✅ |

---

## 两个 AI 的 bug 模式（有意思的部分）

### WorkBuddy 的三个致命 P0（已全部修复）
| 问题 | 后果 |
|---|---|
| `onUpgrade` 是 `deleteTable×5 → createAll()` | **任何 schema 升级 = 用户数据全灭** |
| `deleteInstance` 只软删今日实例，无 `deleteTemplate` | **删了的每日任务明天又回来** |
| 计时只改了 UI 颜色，无 `Timer` 重建 | **「计时中」界面永远不动** |

**它的亮点**：发现了 Flutter 框架的一个坑 —— 带 action 的 SnackBar 默认 `persist = true`，
永不自动消失（`snack_bar.dart:303`）。不显式关掉的话「5 秒内可撤销」就是假话。

### 豆包的两个 P0（已全部修复）
| 问题 | 后果 |
|---|---|
| 编辑中强杀内容全丢 | 30 秒自动保存没触发 + dispose 未执行 |
| 横线本只是浅色背景，没真画线 | 功能是假的 |

**它的亮点**：架构底子干净 —— 上面 WorkBuddy 的三个 P0，它一个都没有。
增量迁移、硬删除、`Timer.periodic` 计时，一开始就写对了。

### 一个误报的教训
豆包曾经报「新建任务按钮点不动」并 blocked 了 1.5 小时。
实测发现按钮完全正常 —— 它把截图预览的 838×1862 当成了实际 1080×2400，
坐标差了 1.2888 倍，点空了 55px。

**教训：AI 报「点不动」时，先怀疑坐标，再怀疑代码。**

---

## 技术栈

| 能力 | 选型 |
|---|---|
| 框架 | Flutter 3.47 / Dart 3.9 |
| 状态管理 | Riverpod（手写 Provider） |
| 数据库 | Drift (SQLite)，**增量迁移** |
| 路由 | go_router |
| 动画 | flutter_animate |
| 精确闹钟 | 原生 AlarmManager（三档降级） |
| 农历 | lunar |
| 通知 | flutter_local_notifications |
| 导出 | archive + share_plus |

---

## 快速开始

```bash
# 环境要求：Flutter 3.47+ / JDK 17 / Android SDK 34

# WorkBuddy 实现
cd workbuddy
flutter pub get
flutter run

# 豆包实现
cd doubao
flutter pub get
flutter run
```

---

## 设计原则

> 「不是功能多就冗余，是**找起来方不方便、用起来麻烦不麻烦**。」

- 功能该有的都要有
- 基础功能必须在 **3 步内**完成

---

## License

[MIT](LICENSE)

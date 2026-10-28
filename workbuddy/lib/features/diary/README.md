# 日记模块（P0 核心难点）

## 排版引擎 PoC（已完成 ✅）

`engine/` 目录下实现了排版引擎的**纯 Dart 核心**，零 Flutter 依赖、可独立单测，验证了三大技术难点的可行性：

```
engine/
├── geo.dart           # GeoRect 轴对齐矩形（纯 Dart，不依赖 dart:ui）
├── text_measure.dart  # TextMeasurer 抽象 + ApproxTextMeasurer 近似实现
├── cjk_layout.dart    # ★ 生产版排版引擎：CjkLayoutEngine（禁则三级降级 + 段落级增量缓存）
├── line_breaker.dart  # 断行器 + 中文标点避头尾（fillSegment 核心算法）
└── flow_layout.dart   # 文字绕排引擎（排除区域表 + 分段渲染）
```

### 核心算法
1. **中文标点避头尾**（`line_breaker.dart`）
   - 禁则字符集：行首禁则（`，。、；：！？）》】」』…` 等）、行尾禁则（`（《【「『` 等）
   - 降级顺序：悬挂标点 → 字距挤压（5% 内）→ 强制带走上一字（PoC 实现悬挂主策略）
2. **文字绕排**（`flow_layout.dart`）
   - 行扫描 + 排除区域表：每行先求可用水平区间，再逐区间贪心排字，文字自然绕开图片

### 验证方式
```bash
flutter test test/features/diary/engine/
```

### PoC 结论
排版引擎核心算法（断行 + 避头尾 + 绕排）在纯 Dart 层面可行，**可作为 V1.0 图文混排的底座**。生产环境需替换 [ApproxTextMeasurer] 为基于 `TextPainter` 的精确测量。

## 预览页：引擎的 UI 出口（已接入 ✅）

编辑器用 `TextField`，换行在框架内部完成，应用层拿不到断行点 —— 所以「避头尾」在编辑态做不到。
只读渲染则可以自己定行、定坐标，因此产品上拆成两件事：

| 场景 | 实现 | 换行由谁决定 |
|---|---|---|
| 写 | `presentation/diary_editor_page.dart`（`TextField`） | 框架（SkParagraph / ICU） |
| 看 | `presentation/diary_preview_page.dart`（只读） | **本引擎**（`CjkLayoutEngine.layoutText`） |

入口：日记列表点卡片 → 预览页 → 右上角「编辑」→ 编辑器。

三个配套件：

- `presentation/widgets/text_painter_measurer.dart` —— `GlyphMeasurer` 的**生产实现**，
  逐 rune 用 `TextPainter` 量真实字宽（按 `rune<<10 | fontSize*4` 缓存，1000 字仅 ~500 次 layout）。
  放在 presentation 层是为了不把 Flutter 依赖带进 `engine/`。
- `presentation/widgets/cjk_preview_painter.dart` —— **一个** CustomPaint 画横线 + 逐行文字；
  每行单独 `TextPainter.layout()`（不给 `maxWidth`，框架无法二次折行），行位由画布坐标
  `topPadding + i * lineHeight` 决定，**不用 SizedBox/Align/Column 堆行**。
- 右侧预留一个全角（`maxLineWidth = 可用宽 - fontSize`）给悬挂标点，悬挂的标点落在右留白里。

验证：`flutter test test/features/diary/presentation/`（6 条：≥6 行 / 行首无禁则 / 全文拼回不丢字 /
每行占宽 ≤ 可用宽 / 单行高度 == 行高 / 1000 字 < 300ms）。

## V1.0 范围（已裁剪，见 ADR-005）
- 两种模板：横线本 / 空白本；字号、字体样式；行高 = 字号 × 1.5
- 图文混排：图片作为**独立块级元素**插入，文字在上下流式排布（见 `core/entities/diary_block.dart`）
- 自动保存：每 30 秒 + 退出页面保存
- 键盘弹出编辑区自动上移

## 降级到 V1.1
- 图片任意位置自由拖拽 / 缩放 / 旋转 + 文字实时避让（绕排引擎已就绪，V1.1 接入手势即可）
- 字距挤压（5%）、强制带走降级策略在**编辑态**生效（只读预览里已生效）

## 关键约束
- 媒体存应用专属目录，Drift 仅存相对路径，**严禁 Base64 入库**
- 排版引擎 Domain 层保持零 Flutter 依赖（已实现）

## TODO
- [x] 排版引擎 PoC（纯 Dart 核心 + 单测）
- [x] 横线/空白本模板渲染（接 TextPainter 测量）
- [x] 引擎接入 UI：只读预览页（CustomPaint + 逐行 TextPainter）
- [x] 增量重排 + 段落级布局缓存（`CjkLayoutEngine` 内置）
- [ ] 编辑态接管断行（需自绘 RenderEditable，V2 议题）
- [ ] 预览页内联渲染图片块（当前只在页头提示图片数量，正文只排文字）
- [ ] 连续滚动 / 仿真翻页（page_flip）切换
- [ ] 图文混排 UI 接入（DiaryBlock 列表 → 引擎渲染）

# UI 打磨设计规范（Team 共用）

> 依据 `UI验收标准.md` R1-R3 / D1-D7，结合现有 `AppColors` / `AppDimens` / `AppTheme`。

## 1. 布局常量（复用现有，禁止魔法数字）

- 水平外边距：`AppDimens.pagePadding`（16）
- 卡片圆角：`AppDimens.cardRadius`（12，已由 `cardTheme` 全局生效）
- 卡片间距：12（卡片与卡片之间）
- 可点击区域最小：`AppDimens.minTapSize`（44）

## 2. 卡片分组（D1）

每个设置区块用 `Card` 包裹（margin: `EdgeInsets.symmetric(horizontal: 16, vertical: 6)`），
内部用 `Column` + `Divider(height: 1)` 分隔行。区块标题用 `_SectionHeader`（已存在）。

## 3. 每行必备（D2/D3）

- `leading: Icon(...)` 语义相关图标
- `subtitle:` 一句话说清作用；**随状态变化**（如授权/未授权不同文案）

## 4. 状态色编码（D4）

| 状态 | 颜色（AppColors） |
|---|---|
| 已开启 / 已授权 | `success`（绿） |
| 警告 / 受限 / 未授权 | `warning`（橙） |
| 激活 / 进行中 | `active`（蓝） |
| 禁用 / 不可用 | `todo`（灰）+ 明确原因 |
| 错误 / 危险 | `danger`（红） |

## 5. 行动入口（D5）

未授权等需用户行动的场景，`trailing` 给 `TextButton('去开启')`，跳系统设置。

## 6. 反馈（D6）

数据变化 → `ref.watch`/`setState` 立即反映；副作用操作 → `ScaffoldMessenger.of(context).showSnackBar(...)`。

## 7. 三态（R3）

- loading：`CircularProgressIndicator`
- empty：`EmptyState`（已存在 `core/widgets/empty_state.dart`）
- error：`EmptyState(icon: Icons.error_outline, ...)`

## 8. 禁止假控件（R1，硬性）

- 已实现 → 真改数据、真联动
- 未实现 → `onChanged: null` / `enabled: false` 灰化 + subtitle 写「后续迭代开放」
- **绝不允许** `onChanged: (_) {}` 或硬编码 `value: true`

## 9. 占位页（R2）

占位页必须用 `EmptyState` 写明「开发中」+ 引导，不许空白 `Scaffold`。
toolbox 的三个插件（朋友生日 / 每日热量 / 采购清单）做成三张卡片，每张灰化 + 「开发中」。

## 10. 一致性（D7）

间距/圆角/字号/颜色全部来自 `AppColors` / `AppDimens` / `Theme.of(context)`。

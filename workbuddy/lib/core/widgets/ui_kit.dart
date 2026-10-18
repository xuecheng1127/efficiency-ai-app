import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';

/// ============================================================================
/// 设计系统组件（UI 打磨统一底座）
/// ============================================================================
///
/// 为什么要有这个文件：UI 验收标准里 **D1 卡片分组 / D2 每行图标 / D3 每行说明 /
/// D7 一致性** 是四条独立要求，如果各页面各写一套 `Card` + `ListTile`，
/// 必然出现「一个文件三种 padding」「有的行有图标有的没有」。
/// 所以把「一行的正确形态」固化成组件，页面只负责填内容。
///
/// **约定（三个页面共同遵守）**：
/// 1. 区块标题一律用 [AppSectionHeader]；
/// 2. 一组设置项一律包在 [AppCard.group]（自动插入带缩进的分隔线）；
/// 3. 设置行一律用 [AppSettingsTile] / [AppSwitchTile] / [AppActionTile] /
///    [AppStatusTile] —— 它们**强制** leading 图标 + subtitle，
///    编译期就拿不到「没有图标的一行」；
/// 4. 未实现的项一律用 [AppDisabledTile]（灰化 + `后续迭代开放`），
///    不允许「看起来能点、点了没反应」（R1）。

/// 区块标题：左侧主题色小标题 + 可选说明。
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        AppDimens.sectionHeaderGap,
        AppDimens.pagePadding,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 分组卡片：圆角 + 细边框 + 极轻阴影，卡片之间留间距（D1）。
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  /// 一组行：**自动**在相邻行之间插入缩进分隔线（与文字左对齐）。
  factory AppCard.group({Key? key, required List<Widget> children}) {
    if (children.isEmpty) {
      return AppCard(key: key, child: const SizedBox.shrink());
    }
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(
          const Divider(
            height: 1,
            thickness: 1,
            // 与图标右侧的文字左边缘对齐（16 padding + 40 图标列）
            indent: AppDimens.pagePadding + AppDimens.leadingIconWidth,
            endIndent: AppDimens.pagePadding,
          ),
        );
      }
      spaced.add(children[i]);
    }
    return AppCard(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: AppDimens.cardPadding),
      child: Column(children: spaced),
    );
  }

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.pagePadding,
        vertical: AppDimens.cardGap / 2,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.8),
      ),
      child: child,
    );
  }
}

/// 一行的图标列：统一宽度，保证所有页面文字左边缘对齐（D7）。
class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon(this.icon, {this.color, this.enabled = true});

  final IconData icon;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: AppDimens.leadingIconWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? (color ?? theme.colorScheme.primary)
                : theme.disabledColor,
          ),
        ),
      ),
    );
  }
}

/// 卡片头部的模块图标（32×32 圆角底板）。
///
/// 工作台 / 工具箱这类「卡片头」都要它 —— 公开出来是为了避免各页面复制
/// 32/9/18 这组尺寸（D7：尺寸只允许来自 token，不允许各写一份）。
class AppModuleIcon extends StatelessWidget {
  const AppModuleIcon(this.icon, {super.key, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => _LeadingIcon(icon, color: color);
}

/// 纯展示行（不可点击）：强制要求图标 + 说明（D2/D3）。
class AppSettingsTile extends StatelessWidget {
  const AppSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _LeadingIcon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}

/// 可点击行：右侧带 arrow，点击有真实动作（R1）。
class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _LeadingIcon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      onTap: onTap,
    );
  }
}

/// 开关行：`onChanged` 必填（没有「点了没反应」的可能），
/// 且**副标题随状态变化**（D3 的更好做法）。
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.subtitle,
    this.subtitleOnEnabled,
    this.subtitleOnDisabled,
  });

  final IconData icon;
  final String title;
  final bool value;

  /// 非空即代表这个开关是**真的**（R1）。
  final ValueChanged<bool> onChanged;

  /// 静态说明（没有状态文案时用）。
  final String subtitle;

  /// 开启时使用的说明（优先于 [subtitle]）。
  final String? subtitleOnEnabled;

  /// 关闭时使用的说明（优先于 [subtitle]）。
  final String? subtitleOnDisabled;

  @override
  Widget build(BuildContext context) {
    final active = (value ? subtitleOnEnabled : subtitleOnDisabled) ?? subtitle;
    return SwitchListTile(
      secondary: _LeadingIcon(icon, color: value ? AppColors.success : null),
      title: Text(title),
      subtitle: Text(active),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// 状态行：把「当前处于什么状态」用颜色/图标编码（D4），
/// 需要用户行动时给入口（D5：trailing 传 `去开启` 按钮）。
class AppStatusTile extends StatelessWidget {
  const AppStatusTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// true → 成功色（绿/主色）；false → 警告色（橙）。
  final bool ok;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _LeadingIcon(
        icon,
        color: ok ? AppColors.success : AppColors.warning,
      ),
      title: Row(
        children: [
          Flexible(child: Text(title)),
          const SizedBox(width: 8),
          Icon(
            ok ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 16,
            color: ok ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: ok ? null : AppColors.warning),
      ),
      trailing: trailing,
    );
  }
}

/// 未实现项：灰化 + 明确写「后续迭代开放」（R1 的合规做法）。
class AppDisabledTile extends StatelessWidget {
  const AppDisabledTile({
    super.key,
    required this.icon,
    required this.title,
    this.reason = '后续迭代开放',
  });

  final IconData icon;
  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // D4 要求「灰 + **明确原因**」。`theme.disabledColor` 的对比度只有 ~2.5:1
    // （深色主题下原因几乎读不出来），所以文字改用 onSurface@0.55（≈4.5:1）；
    // 「禁用」这一层语义由 `enabled: false` + 「未开放」标签 + 灰图标共同表达。
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return ListTile(
      enabled: false,
      leading: _LeadingIcon(icon, enabled: false),
      title: Text(title, style: TextStyle(color: muted)),
      subtitle: Text(reason, style: TextStyle(color: muted)),
      // 用细边框小标签而不是 Chip：Chip 在 ListTile.trailing 里容易被挤到溢出，
      // 而溢出在截图里就是黄黑条纹，比「不好看」更糟。
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '未开放',
          style: theme.textTheme.labelSmall?.copyWith(color: muted),
        ),
      ),
    );
  }
}

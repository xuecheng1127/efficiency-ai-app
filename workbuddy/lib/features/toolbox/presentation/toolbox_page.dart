import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../birthday/presentation/birthday_list_page.dart';
import '../../calorie/presentation/calorie_page.dart';
import '../../location/presentation/location_list_page.dart';
import '../../memo/presentation/memo_list_page.dart';
import '../../shopping/presentation/shopping_list_page.dart';

/// 扩展工具箱：可选插件体系。
///
/// 设计原则（模块2，最高优先级）：
/// - 默认收纳于此，不强制展示在主页；
/// - 用户可一键「添加到主页」，主页长按组件「移除」；
/// - 未添加的功能不请求权限、不占前台资源（数据隔离 + 零感干扰）。
///
/// T23 之后这里的状态分成两类，并且**视觉上必须能区分**：
/// - **备忘录：可用**（绿色 chip + 可点击进入），它是工具箱里第一个真正能用的插件；
/// - 其余 3 个：**开发中**（橙色 chip + 点击只提示），不做「看着能点、点了没反应」的假控件。
///
/// 为什么不做更多「可用」：用户定的「少即是多」—— 没实现的功能摆出来只会增加认知负担。
class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});

  /// 占位插件的唯一点击反馈：明确告知「开发中」，避免静默失败（R1 / D6）。
  void _showComingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('「$name」开发中，敬请期待')));
  }

  void _openPlugin(BuildContext context, _ToolboxPlugin plugin) {
    final builder = plugin.page;
    if (builder == null) {
      _showComingSoon(context, plugin.name);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => builder()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('工具箱')),
      body: ListView(
        padding: const EdgeInsets.only(
          top: AppDimens.sectionHeaderGap,
          bottom: AppDimens.sectionGap,
        ),
        children: [
          const AppSectionHeader('插件原则'),
          AppCard(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppDimens.cardGap),
                Expanded(
                  child: Text(
                    '插件是可选能力：默认只收纳在工具箱，不占主页、不申请权限、'
                    '不占前台资源，添加到主页后才会开始工作。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: AppDimens.lineHeightRatio,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const AppSectionHeader(
            '可选插件',
            subtitle: '5 个插件全部可用：备忘录 / 采购清单 / 朋友生日 / 每日热量 / 途径提醒',
          ),
          for (final plugin in _plugins)
            _PluginCard(
              plugin: plugin,
              onTap: () => _openPlugin(context, plugin),
            ),
        ],
      ),
    );
  }
}

/// 插件元信息
class _ToolboxPlugin {
  const _ToolboxPlugin({
    required this.icon,
    required this.name,
    required this.description,
    this.page,
  });

  final IconData icon;
  final String name;
  final String description;

  /// 非空 = 已实现、可点击进入（绿色「可用」）；null = 占位（橙色「开发中」）。
  ///
  /// 用「页面构造器」而不是 `bool available + if/else`：否则每加一个插件
  /// 都要回头改 `onTap` 分支，插件表就被拆成两处维护。
  final Widget Function()? page;

  bool get available => page != null;
}

/// 插件目录（顺序 = 用户点名的实现顺序）。
final List<_ToolboxPlugin> _plugins = [
  _ToolboxPlugin(
    icon: Icons.sticky_note_2_outlined,
    name: '备忘录',
    description: '想到就记，一句话也能存；置顶重要的，搜一下就能找回来。',
    page: () => const MemoListPage(),
  ),
  _ToolboxPlugin(
    icon: Icons.shopping_basket_outlined,
    name: '采购清单',
    description: '想到什么就记一条，到超市逐项勾选，买完一键恢复成新清单。',
    page: () => const ShoppingListPage(),
  ),
  _ToolboxPlugin(
    icon: Icons.cake_outlined,
    name: '朋友生日',
    description: '记录亲友生日（支持农历），按距离远近排序，7 天内高亮。',
    page: () => const BirthdayListPage(),
  ),
  _ToolboxPlugin(
    icon: Icons.local_fire_department_outlined,
    name: '每日热量',
    description: '三餐随手记，按天汇总摄入热量，只在你打开时才读数据。',
    page: () => const CaloriePage(),
  ),
  _ToolboxPlugin(
    icon: Icons.place_outlined,
    name: '途径提醒',
    description: '走到超市附近提醒买菜、路过快递站提醒取件；到点自动通知。',
    page: () => const LocationReminderListPage(),
  ),
];

/// 单张插件卡：图标 + 名称 + 状态 chip + 说明 + 状态说明行。
class _PluginCard extends StatelessWidget {
  const _PluginCard({required this.plugin, required this.onTap});

  final _ToolboxPlugin plugin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      // `EdgeInsets.zero` 是静态常量字段，不能写 `const EdgeInsets.zero`
      padding: EdgeInsets.zero,
      child: Material(
        // 透明 Material 让 InkWell 的水波纹落在卡片内部，反馈可见（D6）
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        plugin.icon,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppDimens.cardGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                plugin.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: AppDimens.sectionHeaderGap),
                              if (plugin.available)
                                const _StatusChip.available()
                              else
                                const _StatusChip.comingSoon(),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plugin.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // chevron 只在「真的能进去」时才画 —— 不给假的导航暗示
                    if (plugin.available)
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: AppDimens.cardGap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      plugin.available
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      size: 16,
                      color: plugin.available
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: AppDimens.sectionHeaderGap / 2),
                    Expanded(
                      child: Text(
                        plugin.available
                            ? '已可用 · 点击进入，数据只存在本机'
                            : '开发中 · V1 后续接入，届时可一键添加到主页；现在点击只会提示',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: plugin.available
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 状态 chip：绿色=可用，橙色=开发中（颜色编码与全 app 一致：绿=OK，橙=受限）
class _StatusChip extends StatelessWidget {
  const _StatusChip.available() : _label = '可用', _color = AppColors.success;

  const _StatusChip.comingSoon() : _label = '开发中', _color = AppColors.warning;

  final String _label;
  final Color _color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_label, style: TextStyle(fontSize: 11, color: _color)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: _color.withValues(alpha: 0.4)),
      backgroundColor: _color.withValues(alpha: 0.10),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/widgets/ui_kit.dart';
import '../domain/workbench_module.dart';
import '../providers/workbench_providers.dart';
import 'workbench_icons.dart';

/// ============================================================================
/// 工作台配置页
/// ============================================================================
///
/// 只做一件事：决定工作台显示哪些模块。
///
/// **没有「保存」按钮**（刻意）：每个开关一拨就落盘 + 立刻刷新工作台，
/// 放一个"保存"反而会让人以为不点就不生效 —— 而如果它真的需要点，
/// 忘记点就是另一种"假控件"。
///
/// 同时提供：预设一键切换（与空态同一组预设）、恢复未配置（可再次看到空态）。
class WorkbenchConfigPage extends ConsumerWidget {
  const WorkbenchConfigPage({super.key});

  static const Map<String, IconData> _presetIcons = {
    'tasks_only': Icons.checklist_rounded,
    'diary_only': Icons.auto_stories_outlined,
    'both': Icons.space_dashboard_outlined,
  };

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    WorkbenchModule module,
    bool enabled,
  ) async {
    await ref.read(workbenchConfigProvider).toggle(module, enabled);
    if (!context.mounted) return;
    final action = enabled ? '已显示' : '已隐藏';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$action「${module.label}」')));
  }

  Future<void> _applyPreset(
    BuildContext context,
    WidgetRef ref,
    WorkbenchPreset preset,
  ) async {
    await ref.read(workbenchConfigProvider).applyPreset(preset);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已切换到：${preset.label}')));
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('恢复到未配置'),
        content: const Text('清空工作台的模块选择，工作台会回到「还没配置」，可以重新选预设。确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(workbenchConfigProvider).reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清空，工作台回到未配置')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modules = ref.watch(workbenchModulesProvider);
    final matchedPreset = ref.watch(workbenchPresetProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('配置工作台')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.sectionGap),
        children: [
          const AppSectionHeader('显示哪些模块', subtitle: '开关一拨就保存，回工作台立刻生效'),
          AppCard.group(
            children: [
              for (final module in WorkbenchModule.values)
                AppSwitchTile(
                  icon: workbenchModuleIcon(module),
                  title: module.label,
                  value: modules.contains(module),
                  subtitle: module.description,
                  subtitleOnEnabled: '${module.description}（当前显示）',
                  subtitleOnDisabled: '${module.description}（当前隐藏）',
                  onChanged: (v) => _toggle(context, ref, module, v),
                ),
            ],
          ),
          if (modules.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.sectionHeaderGap,
                AppDimens.pagePadding,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppDimens.chipGap),
                  Expanded(
                    child: Text(
                      '两个都关掉的话，工作台会回到「还没配置」空态 —— 想让它有内容，至少打开一个模块。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const AppSectionHeader('预设模式', subtitle: '一键覆盖上面的选择'),
          AppCard.group(
            children: [
              for (final preset in kWorkbenchPresets)
                AppActionTile(
                  icon: _presetIcons[preset.id] ?? Icons.dashboard_outlined,
                  title: preset.label,
                  subtitle: preset.description,
                  onTap: () => _applyPreset(context, ref, preset),
                  trailing: matchedPreset?.id == preset.id
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        )
                      : null,
                ),
            ],
          ),
          const AppSectionHeader('其它'),
          AppCard.group(
            children: [
              AppActionTile(
                icon: Icons.restart_alt,
                title: '恢复到未配置',
                subtitle: '清空选择，工作台回到空态（可重新选预设）',
                iconColor: AppColors.danger,
                onTap: () => _reset(context, ref),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.sectionGap,
              AppDimens.pagePadding,
              0,
            ),
            child: Text(
              modules.isEmpty
                  ? '当前：未配置'
                  : '当前：${modules.map((m) => m.label).join(' + ')}'
                        '${matchedPreset == null ? '（自定义组合）' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

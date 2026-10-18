import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../domain/workbench_module.dart';

/// ============================================================================
/// 工作台配置的读写
/// ============================================================================
///
/// 存储复用已有的 `app_settings.json`（`SettingsStore`）：
/// 本工程没有 `shared_preferences` 依赖，而设置文件已经是**唯一**的用户偏好入口，
/// 再引入第二个存储源会造成"两个地方都有配置、谁真谁假"的问题。
///
/// 落盘字段：`workbenchModules: ["tasks", "diary"]`（顺序 = 显示顺序）。
/// 空列表 = 还没配置 → 工作台显示空态 + 预设。

/// 当前启用的模块（已容错：未知 id 会被丢掉，坏配置等价于未配置）。
final workbenchModulesProvider = Provider<List<WorkbenchModule>>((ref) {
  final ids = ref.watch(appSettingsProvider).workbenchModules;
  return parseWorkbenchModules(ids);
});

/// 是否已经配置过（空态判据就是它）。
final workbenchConfiguredProvider = Provider<bool>((ref) {
  return ref.watch(workbenchModulesProvider).isNotEmpty;
});

/// 配置页用：当前配置对应的预设（非预设组合时为 null）。
final workbenchPresetProvider = Provider<WorkbenchPreset?>((ref) {
  return matchPreset(ref.watch(workbenchModulesProvider));
});

/// 写配置（所有入口都走这里，保证「立即落盘 + 立即刷新 UI」只有一份实现）。
class WorkbenchConfig {
  const WorkbenchConfig(this._ref);

  final Ref _ref;

  AppSettingsNotifier get _settings => _ref.read(appSettingsProvider.notifier);

  /// 应用一个预设（空态卡片、配置页都用）。
  Future<void> applyPreset(WorkbenchPreset preset) {
    return _settings.patch(workbenchModules: workbenchModuleIds(preset.modules));
  }

  /// 直接设定模块列表（顺序敏感）。
  Future<void> setModules(List<WorkbenchModule> modules) {
    return _settings.patch(workbenchModules: workbenchModuleIds(modules));
  }

  /// 打开/关闭单个模块。
  ///
  /// 关闭时不改变其它模块的顺序；打开时追加到末尾（用户心智：新加的排在后面）。
  Future<void> toggle(WorkbenchModule module, bool enabled) {
    final current = [..._ref.read(workbenchModulesProvider)];
    final has = current.contains(module);
    if (enabled && !has) {
      current.add(module);
    } else if (!enabled && has) {
      current.remove(module);
    } else {
      return Future<void>.value();
    }
    return setModules(current);
  }

  /// 清空配置 → 工作台回到「还没配置」空态（配置页的「恢复未配置」用它）。
  Future<void> reset() {
    return _settings.patch(workbenchModules: const <String>[]);
  }
}

final workbenchConfigProvider = Provider<WorkbenchConfig>(WorkbenchConfig.new);

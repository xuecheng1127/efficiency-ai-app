import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 工作台显示模式
enum WorkbenchMode {
  /// 未配置
  unconfigured,
  /// 只看任务
  tasksOnly,
  /// 只看日记
  diaryOnly,
  /// 任务 + 日记
  both,
}

class WorkbenchModeNotifier extends StateNotifier<WorkbenchMode> {
  WorkbenchModeNotifier() : super(WorkbenchMode.unconfigured) {
    _load();
  }

  static const _key = 'workbench_mode';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    state = switch (v) {
      'tasks' => WorkbenchMode.tasksOnly,
      'diary' => WorkbenchMode.diaryOnly,
      'both' => WorkbenchMode.both,
      _ => WorkbenchMode.unconfigured,
    };
  }

  Future<void> set(WorkbenchMode m) async {
    state = m;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, switch (m) {
      WorkbenchMode.unconfigured => '',
      WorkbenchMode.tasksOnly => 'tasks',
      WorkbenchMode.diaryOnly => 'diary',
      WorkbenchMode.both => 'both',
    });
  }
}

final workbenchModeProvider =
    StateNotifierProvider<WorkbenchModeNotifier, WorkbenchMode>(
        (ref) => WorkbenchModeNotifier());

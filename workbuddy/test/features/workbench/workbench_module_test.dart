import 'package:efficiency_app/core/settings/app_settings.dart';
import 'package:efficiency_app/features/workbench/domain/workbench_module.dart';
import 'package:flutter_test/flutter_test.dart';

/// 工作台配置的**纯逻辑**测试（不碰 widget / 数据库）。
///
/// 这些断言覆盖三件容易悄悄坏掉的事：
/// 1. 用户配置的顺序必须被保留（工作台按顺序渲染）；
/// 2. 坏配置（未知 id / 重复 / 类型不对）不能让应用崩，只能被容忍；
/// 3. 空列表 == 未配置（工作台据此显示空态），不能被误解成"配置成空"。
void main() {
  group('parseWorkbenchModules', () {
    test('保留用户选择的顺序', () {
      expect(parseWorkbenchModules(['diary', 'tasks']), [
        WorkbenchModule.diary,
        WorkbenchModule.tasks,
      ]);
      expect(parseWorkbenchModules(['tasks', 'diary']), [
        WorkbenchModule.tasks,
        WorkbenchModule.diary,
      ]);
    });

    test('未知 id 被丢掉，不影响已知模块', () {
      expect(parseWorkbenchModules(['nope', 'tasks', '', 'diary']), [
        WorkbenchModule.tasks,
        WorkbenchModule.diary,
      ]);
    });

    test('重复 id 只保留一次', () {
      expect(parseWorkbenchModules(['tasks', 'tasks']), [
        WorkbenchModule.tasks,
      ]);
    });

    test('空列表 = 未配置', () {
      expect(parseWorkbenchModules(const []), isEmpty);
      expect(parseWorkbenchModules(const ['unknown_only']), isEmpty);
    });
  });

  test('ids ↔ modules 往返一致', () {
    final ids = workbenchModuleIds([WorkbenchModule.diary, WorkbenchModule.tasks]);
    expect(ids, ['diary', 'tasks']);
    expect(parseWorkbenchModules(ids), [
      WorkbenchModule.diary,
      WorkbenchModule.tasks,
    ]);
  });

  group('preset', () {
    test('三个预设覆盖任务 / 日记 / 两者', () {
      expect(kWorkbenchPresets.map((p) => p.id), [
        'tasks_only',
        'diary_only',
        'both',
      ]);
      expect(kWorkbenchPresets.every((p) => p.modules.isNotEmpty), isTrue);
    });

    test('命中预设时能识别出来', () {
      expect(
        matchPreset([WorkbenchModule.tasks, WorkbenchModule.diary])?.id,
        'both',
      );
      expect(matchPreset([WorkbenchModule.diary])?.id, 'diary_only');
    });

    test('顺序不同不算命中预设（它是自定义组合）', () {
      expect(matchPreset([WorkbenchModule.diary, WorkbenchModule.tasks]), isNull);
    });

    test('未配置不算任何预设', () {
      expect(matchPreset(const []), isNull);
    });
  });

  group('AppSettings 持久化', () {
    test('workbenchModules 能往返 JSON', () {
      const s = AppSettings(workbenchModules: ['tasks', 'diary']);
      final restored = AppSettings.fromJson(s.toJson());
      expect(restored.workbenchModules, ['tasks', 'diary']);
    });

    test('默认是未配置（空列表）', () {
      expect(const AppSettings().workbenchModules, isEmpty);
    });

    test('字段坏掉时退回空列表，而不是抛异常', () {
      expect(
        AppSettings.fromJson(const {'workbenchModules': 'tasks'}).workbenchModules,
        isEmpty,
      );
      expect(
        AppSettings.fromJson(const {
          'workbenchModules': [1, null, 'tasks'],
        }).workbenchModules,
        ['tasks'],
      );
    });

    test('copyWith 能单独改工作台配置，且不动其它字段', () {
      const base = AppSettings(volume: 42, workbenchModules: ['diary']);
      final next = base.copyWith(workbenchModules: ['tasks']);
      expect(next.workbenchModules, ['tasks']);
      expect(next.volume, 42);
      expect(next.themeMode, base.themeMode);
    });
  });
}

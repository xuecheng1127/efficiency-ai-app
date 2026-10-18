/// ============================================================================
/// 工作台：可配置的模块集合
/// ============================================================================
///
/// **纯 Dart，零 Flutter 依赖** —— 配置语义（哪些模块、什么预设）与渲染无关，
/// 可以脱离 widget 单测（见 `test/features/workbench/workbench_module_test.dart`）。
///
/// 设计边界（与 PRD 模块4 对齐）：
/// - P1 只做「选择显示哪几个模块」，**不做**拖拉拽布局 / 无限分区 / 表格模式。
/// - 模块内容**复用**各自 feature 的 Repository / Provider，工作台不复制业务逻辑。
library;

/// 工作台可显示的模块。
enum WorkbenchModule {
  /// 今日任务（复用 `TaskRepository` / `todayInstancesProvider`）
  tasks(id: 'tasks', label: '今日任务', description: '查看今日进度，点进任务列表开始计时'),

  /// 日记（复用 `DiaryRepository` / `diaryRowsProvider`）
  diary(id: 'diary', label: '日记', description: '看最近一篇，或直接写今天');

  const WorkbenchModule({
    required this.id,
    required this.label,
    required this.description,
  });

  /// 落盘的稳定标识（**不要**用 `index` 或 `name`：改名会毁掉用户配置）。
  final String id;

  /// 界面上显示的名字。
  final String label;

  /// 一行说明（设置/配置页用）。
  final String description;

  /// 按 id 找回模块；未知 id 返回 null（**不抛异常**，配置坏掉不能让应用崩）。
  static WorkbenchModule? byId(String? id) {
    for (final m in WorkbenchModule.values) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// 解析持久化的 id 列表。
///
/// 三步都做容错：去重复、丢未知 id、**保持用户在配置页选择的顺序**。
/// 返回空列表 = 还没配置（不是"配置成什么都不显示"）。
List<WorkbenchModule> parseWorkbenchModules(List<String> ids) {
  final seen = <WorkbenchModule>{};
  final out = <WorkbenchModule>[];
  for (final raw in ids) {
    final m = WorkbenchModule.byId(raw);
    if (m == null) continue;
    if (seen.add(m)) out.add(m);
  }
  return out;
}

/// 反向：模块列表 → 落盘用的 id 列表（顺序即显示顺序）。
List<String> workbenchModuleIds(List<WorkbenchModule> modules) {
  return [for (final m in modules) m.id];
}

/// 预设模式：空态下让用户一键起步，而不是先去配置页想「我该开什么」。
class WorkbenchPreset {
  const WorkbenchPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.modules,
  });

  final String id;
  final String label;
  final String description;
  final List<WorkbenchModule> modules;
}

/// 三个预设（任务 / 日记 / 两者都要）——正好覆盖用户最可能的三种用法。
const List<WorkbenchPreset> kWorkbenchPresets = [
  WorkbenchPreset(
    id: 'tasks_only',
    label: '只看任务',
    description: '工作台就是一张任务清单，最省事',
    modules: [WorkbenchModule.tasks],
  ),
  WorkbenchPreset(
    id: 'diary_only',
    label: '只看日记',
    description: '工作台变成日记本入口，专注记录',
    modules: [WorkbenchModule.diary],
  ),
  WorkbenchPreset(
    id: 'both',
    label: '任务 + 日记',
    description: '上面看今天要做什么，下面记今天做了什么',
    modules: [WorkbenchModule.tasks, WorkbenchModule.diary],
  ),
];

/// 当前配置是否命中某个预设（配置页用来显示「当前：任务 + 日记」这类状态）。
WorkbenchPreset? matchPreset(List<WorkbenchModule> modules) {
  if (modules.isEmpty) return null;
  final target = workbenchModuleIds(modules);
  for (final p in kWorkbenchPresets) {
    final ids = workbenchModuleIds(p.modules);
    if (ids.length != target.length) continue;
    var same = true;
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != target[i]) {
        same = false;
        break;
      }
    }
    if (same) return p;
  }
  return null;
}

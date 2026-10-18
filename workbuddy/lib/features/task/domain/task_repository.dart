import 'task_enums.dart';
import 'task_instance.dart';

/// 任务仓库抽象接口：双层模型（模板 + 实例），隔离 Drift 实现（依赖倒置）。
abstract interface class TaskRepository {
  /// 监听「今日实例」列表（已完成沉底，其余按 id 升序）。
  Stream<List<TaskInstance>> watchTodayInstances(DateTime today);

  /// 新增模板（startDate 默认今天）。
  Future<int> addTemplate({
    required TaskType type,
    required String title,
    required RepeatMode repeatMode,
    List<int> repeatDays = const [],
  });

  /// 惰性补齐（应用启动 / 回前台时调用，幂等）。
  Future<void> backfill(DateTime today);

  /// 开始计时（实例，自动切为进行中）。
  Future<void> startTimer(int instanceId);

  /// 完成实例（归档耗时并切为已完成）。
  Future<void> completeInstance(int instanceId);

  /// 取消完成（已完成 → 未完成，UNDO-COMPLETE）。
  ///
  /// 语义：状态回 `todo`、清 `completedAt`、清归档耗时（`accumulatedSeconds = 0`），
  /// 这样「取消完成后」的耗时不会留下上一次完成的假记录。
  ///
  /// 只对 `done` 生效（条件写在 UPDATE 的 WHERE 里）：万一被误调用，
  /// 也绝不可能掐掉一条正在跑的计时（验收 §4）。
  Future<void> uncompleteInstance(int instanceId);

  /// 取消计时（实例，回到未完成）。
  Future<void> cancelTimer(int instanceId);

  /// 删除实例（软删除，保留历史）。
  Future<void> deleteInstance(int instanceId);

  /// 删除任务（**模板级**，软删除）。
  ///
  /// 语义：把模板归档（`archivedAt`）+ 该模板下的实例全部软删。
  /// 只删实例是错的 —— 每日任务明天会被 backfill 从 `lastOccurrenceDate`
  /// 继续补回来，用户会看到「删了又回来」（P0-2）。
  /// [now] 仅供测试注入固定时间。
  Future<void> deleteTemplate(int templateId, {DateTime? now});
}

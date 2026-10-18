import 'task_instance.dart';
import 'task_template.dart';

/// 任务仓库接口（T01 规格 §10.3：依赖倒置）
///
/// 由 Domain 层定义接口，Data 层（Drift 实现）负责具体查询。
/// Domain / Engine 层只依赖本接口，不依赖任何数据库实现。
///
/// 方法命名与语义沿用旧 Isar 版 TaskRepository（presentation 层仅调字段），
/// 参数/返回类型已按双层模型调整：
/// - 模板：TaskTemplate（规则）；实例：TaskInstance（某天的事实）；
/// - [TaskWithOccurrence]：今日列表「模板 + 实例」组合视图。
abstract interface class TaskRepository {
  // ==================== 任务模板 ====================

  /// 查询所有未归档的任务模板（archivedAt IS NULL）
  Future<List<TaskTemplate>> getAllTasks();

  /// 监听未归档模板变化（Riverpod Stream 使用）
  Stream<List<TaskTemplate>> watchAllTasks();

  /// 新增任务模板，返回新模板 id
  Future<int> addTask(TaskTemplate task);

  /// 更新任务模板（快照原则：不影响已生成实例）
  Future<void> updateTask(TaskTemplate task);

  /// 归档模板（软删除：设 archivedAt，停止重复、保留历史实例）
  Future<void> archiveTask(int templateId);

  /// 删除模板与其全部实例（硬删除，不可恢复）
  Future<void> deleteTask(int templateId);

  // ==================== 当日实例 / 惰性补齐 ====================

  /// 应用启动 / 回前台时执行惰性补齐（规格 §3、§4.1）
  ///
  /// [today] 归一化日期（调用方负责传当天 00:00:00）。
  /// 幂等：重复调用不产生重复实例（依赖 UNIQUE(templateId, occurrenceDate)）。
  Future<void> backfillOnAppStart(DateTime today);

  /// 获取"今日任务"完整列表（先补齐当日实例，再返回模板+实例配对）
  Future<List<TaskWithOccurrence>> getTodayTasks();

  /// 监听"今日任务"变化（模板/实例任一变化时自动刷新）
  Stream<List<TaskWithOccurrence>> watchTodayTasks();

  /// 查询某模板在指定日期的实例
  Future<TaskInstance?> getOccurrence(int templateId, DateTime date);

  /// 按实例主键查询（计时器回填/前台服务联动使用）
  Future<TaskInstance?> getOccurrenceById(int occurrenceId);

  /// 查询某模板某日期的全部实例（含历史与软删除，供统计/归档）
  Future<List<TaskInstance>> getOccurrencesByDate(
      int templateId, DateTime date);

  // ==================== 三态流转（实例级） ====================

  /// 点击"开始计时" → 进行中（写入 startedAt，计时唯一真源）
  Future<void> startTask(int occurrenceId);

  /// 点击"完成" → 已完成，并归档本次耗时
  ///
  /// [extraSeconds]：本次计时累计秒数（增量加入 accumulatedSeconds）。
  Future<void> completeTask(int occurrenceId, {int extraSeconds = 0});

  /// 重置为未完成（撤销误操作；清空 startedAt/completedAt）
  Future<void> reopenTask(int occurrenceId);

  /// 停止计时（回到未完成，保留已累计秒数）
  Future<void> pauseTask(int occurrenceId, {int elapsedSeconds = 0});
}

/// 「任务模板 + 当日实例」组合视图，供 UI 一次性拿到完整信息
class TaskWithOccurrence {
  final TaskTemplate task;
  final TaskInstance occurrence;

  const TaskWithOccurrence({required this.task, required this.occurrence});
}

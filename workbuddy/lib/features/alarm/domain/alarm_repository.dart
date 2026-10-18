import 'alarm_enums.dart';
import 'scheduled_alarm.dart';

/// 闹钟仓库抽象接口（依赖倒置：Domain 定接口，Data 给实现）。
///
/// T10 的职责边界：**只负责持久化**。
/// 「什么时候重建闹钟」「权限变了怎么重排」分别属于 T11 / T12。
abstract interface class AlarmRepository {
  /// 调度闹钟：把 11 个参数**同步落盘**，随后再交给原生侧调度。
  ///
  /// 同一任务重复调度走「覆盖」语义（不产生重复记录）。
  /// 返回值即落盘后的真实记录。
  Future<ScheduledAlarm> scheduleForTask({
    required int taskId,
    required int hour,
    required int minute,
    required String repeatRule,
    List<int> weekdays = const [],
    DateTime? scheduledDate,
    int? advanceMinutes,
    String ringtone = 'default',
    int volume = 80,
    bool snoozeEnabled = true,
    int snoozeMinutes = 5,
    AlarmTier tier = AlarmTier.inexact,
  });

  /// 取消并删除某任务的闹钟记录。
  Future<void> cancelForTask(int taskId);

  /// 读出全部闹钟记录（启动时完整读回用）。
  Future<List<ScheduledAlarm>> loadAll();

  /// 表的**独立**枚举能力：只凭本表回答「有哪些闹钟要重建」（T11 使用）。
  Future<List<ScheduledAlarm>> loadEnabled();

  /// 响应式监听全部闹钟（界面展示用）。
  Stream<List<ScheduledAlarm>> watchAll();

  /// 全局提醒总开关（设置页）：批量置 `enabled`，返回影响行数。
  ///
  /// **为什么不只在 UI 层「取消全部闹钟」**：`enabled` 是原生侧重建的**真源**
  /// （`AlarmStore` 只认 `enabled = 1`）。把它置 0，才能保证「重启 App / 重启手机后
  /// 也不会响」；只调一次 native `cancel` 的话，开机重建（`BootReceiver` → `rescheduleAll`）
  /// 会照表把闹钟重新武装回来 —— 那就是个假开关。
  ///
  /// 注意：本方法**不改**调度逻辑，只改一个布尔列，T19 的扫描/幂等不受影响。
  Future<int> setAllEnabled(bool enabled);

  /// 清理「已经过去的一次性闹钟」（T11），返回删除条数。
  ///
  /// 判定与 [ScheduledAlarm.isExpiredOnce] 同规则；重复闹钟（daily / weekly）永不会被清。
  /// 启动时调用一次即可：这类记录再也不可能触发，留着只会让任务条目显示一个假的「已设闹钟」。
  Future<int> pruneExpiredOnce(DateTime now);
}

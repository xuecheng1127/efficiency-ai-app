import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/platform/alarm_channel.dart';
import '../alarm_log.dart';
import '../domain/alarm_enums.dart';
import '../domain/alarm_repository.dart';
import '../domain/scheduled_alarm.dart';
import 'alarm_mapper.dart';

/// [AlarmRepository] 的 Drift 实现。
///
/// 写入语义：**先删后插**（在同一事务内）。配合表上 `task_id` 的 UNIQUE 约束，
/// 结构性地保证「一个任务至多一条闹钟记录」，重复调度只更新不新增。
class AlarmRepositoryImpl implements AlarmRepository {
  AlarmRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
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
  }) async {
    final now = DateTime.now();
    // once 必须有具体执行日：未指定时取今天（下游重建不需要再猜）
    final effectiveDate = repeatRule == 'once'
        ? _dateOnly(scheduledDate ?? now)
        : scheduledDate;

    final row = await _db.transaction(() async {
      // 同一任务至多一条：先删后插，避免重复行，也避免 UNIQUE 冲突
      await (_db.delete(
        _db.scheduledAlarms,
      )..where((t) => t.taskId.equals(taskId))).go();

      final id = await _db
          .into(_db.scheduledAlarms)
          .insert(
            ScheduledAlarmsCompanion.insert(
              taskId: taskId,
              hour: hour,
              minute: minute,
              repeatRule: repeatRule,
              weekdays: Value(AlarmMapper.encodeWeekdays(weekdays)),
              scheduledDate: Value(effectiveDate),
              advanceMinutes: Value(advanceMinutes),
              ringtone: Value(ringtone),
              volume: Value(volume),
              snoozeEnabled: Value(snoozeEnabled),
              snoozeMinutes: Value(snoozeMinutes),
              tier: Value(tier.name),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      return (_db.select(
        _db.scheduledAlarms,
      )..where((t) => t.id.equals(id))).getSingle();
    });

    final alarm = AlarmMapper.toDomain(row);
    // 证据 #5：写入即打日志，可与启动时的读回日志逐字段对照
    alarmLog('persisted(taskId=${alarm.taskId}): $alarm');

    // 落盘成功后才交给原生调度；原生侧尚未接入时降级，不影响持久化结果
    final dispatch = await _dispatchToPlatform(alarm);
    alarmLog('platform dispatch(taskId=${alarm.taskId}): $dispatch');

    return alarm;
  }

  @override
  Future<void> cancelForTask(int taskId) async {
    final rows = await (_db.delete(
      _db.scheduledAlarms,
    )..where((t) => t.taskId.equals(taskId))).go();
    alarmLog('cancelled(taskId=$taskId): deleted rows=$rows');

    try {
      await AlarmScheduler.cancel(taskId);
    } catch (e) {
      alarmLog('platform cancel skipped(taskId=$taskId): ${e.runtimeType}');
    }
  }

  @override
  Future<List<ScheduledAlarm>> loadAll() async {
    final rows = await (_db.select(
      _db.scheduledAlarms,
    )..orderBy([(t) => OrderingTerm.asc(t.taskId)])).get();
    return rows.map(AlarmMapper.toDomain).toList();
  }

  @override
  Future<int> setAllEnabled(bool enabled) async {
    final changed =
        await (_db.update(_db.scheduledAlarms)
              ..where((t) => t.enabled.equals(!enabled)))
            .write(ScheduledAlarmsCompanion(enabled: Value(enabled)));
    alarmLog('setAllEnabled($enabled): updated rows=$changed');
    return changed;
  }

  @override
  Future<List<ScheduledAlarm>> loadEnabled() async {
    final rows =
        await (_db.select(_db.scheduledAlarms)
              ..where((t) => t.enabled.equals(true))
              ..orderBy([
                (t) => OrderingTerm.asc(t.hour),
                (t) => OrderingTerm.asc(t.minute),
              ]))
            .get();
    return rows.map(AlarmMapper.toDomain).toList();
  }

  @override
  Stream<List<ScheduledAlarm>> watchAll() {
    return (_db.select(_db.scheduledAlarms)
          ..orderBy([(t) => OrderingTerm.asc(t.taskId)]))
        .watch()
        .map((rows) => rows.map(AlarmMapper.toDomain).toList());
  }

  @override
  Future<int> pruneExpiredOnce(DateTime now) async {
    // 只查 once 的行即可：daily / weekly 的 nextTriggerAt 永远是未来时刻
    final rows = await (_db.select(
      _db.scheduledAlarms,
    )..where((t) => t.repeatRule.equals('once'))).get();
    final expired = rows
        .map(AlarmMapper.toDomain)
        .where((a) => a.isExpiredOnce(now))
        .toList();
    if (expired.isEmpty) {
      alarmBootLog(
        'prune: nothing to prune (${rows.length} once row(s), all still in the future)',
      );
      return 0;
    }
    final ids = expired.map((a) => a.id).toList();
    final deleted = await (_db.delete(
      _db.scheduledAlarms,
    )..where((t) => t.id.isIn(ids))).go();
    alarmBootLog(
      'prune: deleted $deleted expired once alarm(s) ids=$ids '
      'taskIds=${expired.map((a) => a.taskId).toList()} '
      '(trigger already passed; AlarmManager 侧的重排由原生 rescheduleAll 跳过)',
    );
    return deleted;
  }

  /// 把调度意图交给原生侧。返回值仅用于日志（不改变持久化结果）。
  Future<String> _dispatchToPlatform(ScheduledAlarm alarm) async {
    if (!alarm.enabled) return 'skipped(disabled)';
    try {
      await AlarmScheduler.schedule(
        taskId: alarm.taskId,
        triggerAt: alarm.nextTriggerAt(DateTime.now()),
        enabled: alarm.enabled,
      );
      return 'ok';
    } catch (e) {
      // 原生侧 MethodChannel 尚未接入（见 README TODO）。
      // T10 只交付持久化能力，这里必须降级而不是让整个调度失败。
      return 'skipped(no-native-impl): ${e.runtimeType}';
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

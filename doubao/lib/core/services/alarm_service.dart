import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/settings/providers/app_settings.dart';
import '../database/app_database.dart';
import '../../features/task/domain/task_enums.dart';
import '../../features/task/domain/task_template.dart';

/// 闹钟提醒服务（模块1 闹钟提醒系统）
///
/// 职责：
/// - 通过 MethodChannel 调用原生 AlarmManager.setExactAndAllowWhileIdle
///   （精确闹钟，防电池优化杀死）；
/// - 计算下一次触发时刻（复用任务重复规则语义，与今日列表一致）；
/// - 任务增删改 / 全局设置变化时联动调度或取消。
///
/// T01 适配说明：闹钟绑定完整实现在 T10，本服务已按新双层模型
/// （TaskTemplate + alarmConfigJson）调整参数类型；add_task_page /
/// settings_page 的调用点保持不变，仅字段来源改为新模型。
///
/// 权限策略（场景化申请 + 降级兜底）：
/// - Android 12+ 精确闹钟权限 SCHEDULE_EXACT_ALARM 默认拒绝，
///   首次绑定闹钟时场景化检查 [canScheduleExactAlarms] 并引导开启；
/// - 未授权时原生自动降级 setWindow（近精确，≤1 分钟窗口），不崩溃。
class AlarmService {
  AlarmService._();

  static final AlarmService instance = AlarmService._();

  static const MethodChannel _channel = MethodChannel('com.efficiency.app/alarm');

  /// 内置铃音列表（对应原生 res/raw/alarm_tone_1..3.wav）
  static const List<String> builtInRingtones = ['晨曦', '微风', '雨落'];

  /// 提前提醒选项（分钟，需求：支持提前 15/30 分钟提醒）
  static const List<int> advanceOptions = [0, 15, 30];

  // ==================== 调度 / 取消 ====================

  /// 计算任务下一次触发时刻（epoch millis）
  ///
  /// 语义与 BackfillEngine.matchesRepeatRule 保持一致：
  /// - 单次：计划日期（startDate）当天 alarmTime - 提前量；已过期则不再排；
  /// - 每日：今天未到则今天，已到则明天；
  /// - 每周：从今天起最近一个匹配固定日。
  /// 闹钟时间（时分）与提前量来自 alarmConfigJson（T01 起存 JSON）。
  /// [now] 用于测试注入，默认当前时间。
  int? nextTriggerMillis(
    TaskTemplate template, {
    DateTime? now,
  }) {
    if (!template.alarmEnabled) return null;

    final config = _parseAlarmConfig(template.alarmConfigJson);
    if (config == null) return null;

    final alarmTime = config['time'] as String?;
    if (alarmTime == null) return null;
    final parts = alarmTime.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final base = now ?? DateTime.now();
    final advance = config['advanceMinutes'] as int? ?? 0;
    // 构造某天的触发时刻：alarmTime(时分) - 提前量
    DateTime? candidateAt(DateTime day) =>
        DateTime(day.year, day.month, day.day, hour, minute)
            .subtract(Duration(minutes: advance));

    switch (template.repeatMode) {
      case RepeatRule.once:
        final t = candidateAt(template.startDate);
        return (t != null && t.isAfter(base)) ? t.millisecondsSinceEpoch : null;
      case RepeatRule.daily:
        final today = candidateAt(base);
        if (today != null && today.isAfter(base)) return today.millisecondsSinceEpoch;
        return candidateAt(base.add(const Duration(days: 1)))?.millisecondsSinceEpoch;
      case RepeatRule.weekly:
        for (var i = 0; i < 7; i++) {
          final day = base.add(Duration(days: i));
          if (template.repeatDays.contains(day.weekday)) {
            final t = candidateAt(day);
            if (t != null && t.isAfter(base)) return t.millisecondsSinceEpoch;
          }
        }
        return null;
    }
  }

  /// 调度任务闹钟（写库或修改闹钟设置后调用）
  Future<bool> scheduleTaskAlarm(
    TaskTemplate template,
    AppSettings settings,
  ) async {
    final trigger = nextTriggerMillis(template);
    if (trigger == null) return false;
    if (!settings.taskReminderEnabled) return false;

    final config = _parseAlarmConfig(template.alarmConfigJson);
    final time = config?['time'] as String?;
    final parts = time?.split(':');
    final hour = (parts != null && parts.length == 2) ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = (parts != null && parts.length == 2) ? int.tryParse(parts[1]) ?? 0 : 0;

    try {
      await _channel.invokeMethod<bool>('scheduleTaskAlarm', {
        'taskId': template.id,
        'title': template.title,
        'triggerAtMillis': trigger,
        'hourOfDay': hour,
        'minute': minute,
        'repeatRule': template.repeatMode.index,
        'weekdays': template.repeatDays,
        'scheduledDateMillis': template.startDate.millisecondsSinceEpoch,
        'advanceMinutes': config?['advanceMinutes'] ?? 0,
        'ringtone': settings.alarmRingtone,
        'volume': settings.alarmVolume,
        'snoozeEnabled': settings.snoozeEnabled,
        'snoozeMinutes': settings.snoozeMinutes,
      });
      // T10: 调度成功后同步落盘（upsert by taskId）
      await _persistScheduledAlarm(
        taskId: template.id!,
        hour: hour,
        minute: minute,
        repeatRule: template.repeatMode.name,
        weekdays: template.repeatDays.isEmpty
            ? null
            : template.repeatDays.join(','),
        scheduledDateMillis: trigger,
        advanceMinutes: config?['advanceMinutes'] ?? 0,
        ringtone: settings.alarmRingtone,
        volume: settings.alarmVolume.toDouble(),
        snoozeEnabled: settings.snoozeEnabled ? 1 : 0,
        snoozeMinutes: settings.snoozeMinutes,
      );
      return true;
    } on PlatformException catch (e) {
      debugPrint('调度闹钟失败: ${e.message}');
      return false;
    }
  }

  /// T10: 把已调度闹钟写入 scheduled_alarms 表（按 taskId upsert）
  Future<void> _persistScheduledAlarm({
    required int taskId,
    required int hour,
    required int minute,
    required String repeatRule,
    String? weekdays,
    required int scheduledDateMillis,
    required int advanceMinutes,
    required String ringtone,
    required double volume,
    required int snoozeEnabled,
    required int snoozeMinutes,
  }) async {
    final db = AppDatabase.instance;
    // 先删旧记录（同一 taskId 只保留最新一条），再插入
    await (db.delete(db.scheduledAlarms)
          ..where((a) => a.taskId.equals(taskId)))
        .go();
    await db.into(db.scheduledAlarms).insert(
          ScheduledAlarmsCompanion.insert(
            taskId: taskId,
            hour: hour,
            minute: minute,
            repeatRule: repeatRule,
            weekdays: Value(weekdays),
            scheduledDate:
                DateTime.fromMillisecondsSinceEpoch(scheduledDateMillis),
            advanceMinutes: advanceMinutes,
            ringtone: ringtone,
            volume: volume,
            snoozeEnabled: Value(snoozeEnabled),
            snoozeMinutes: Value(snoozeMinutes),
          ),
        );
  }

  /// 取消任务闹钟（删除 / 归档 / 关闭任务闹钟时调用）
  Future<void> cancelTaskAlarm(int taskId) async {
    try {
      await _channel.invokeMethod<void>('cancelTaskAlarm', taskId);
    } on PlatformException catch (e) {
      debugPrint('取消闹钟失败: ${e.message}');
    }
  }

  // ==================== 权限 ====================

  /// 是否拥有精确闹钟权限（Android 12+ 需要；未授权原生会降级）
  Future<bool> canScheduleExactAlarms() async {
    try {
      final ok = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return ok ?? true;
    } on PlatformException {
      return true; // 通道不可用时视为可用，避免反复打扰
    }
  }

  /// 引导用户到系统设置开启精确闹钟权限
  Future<void> requestExactAlarmPermission() async {
    try {
      await _channel.invokeMethod<void>('requestExactAlarmPermission');
    } on PlatformException {
      // 部分 ROM 无此设置页，静默忽略，原生已降级兜底
    }
  }

  /// T12：前台兜底——重排全部已存闹钟（权限档位变化后调用）
  ///
  /// vivo ROM 不发 ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED，
  /// 用户在系统设置改权限后，应用回到前台时手动触发重排。
  Future<void> rescheduleAll() async {
    try {
      await _channel.invokeMethod<void>('rescheduleAll');
    } on PlatformException catch (e) {
      debugPrint('重排闹钟失败: ${e.message}');
    }
  }

  /// T19: B 档周期扫描兜底——扫描过期未响的闹钟，补一次响铃
  /// 幂等：用 last_rescanned_at 标记，避免重复补响
  Future<void> rescanMissedAlarms() async {
    try {
      await _channel.invokeMethod<void>('rescanMissedAlarms');
    } on PlatformException catch (e) {
      debugPrint('扫描漏响闹钟失败: ${e.message}');
    }
  }

  /// 解析 alarmConfigJson（T01 结构：{"time":"HH:mm","advanceMinutes":15}）
  Map<String, dynamic>? _parseAlarmConfig(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null; // 配置损坏时不调度，避免崩溃
    }
  }
}

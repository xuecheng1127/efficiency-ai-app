import '../../../core/notifications/app_notifications.dart';
import '../domain/birthday.dart';

/// 生日提醒的排期（**薄封装**：算下一次生日 → 交给本地通知）。
///
/// 与「闹钟链路」的关系（如实标注）：
/// 本应用的 `scheduled_alarms.task_id` 是**指向 `task_templates` 的外键**，
/// 生日没有任务模板，硬塞进去要么造一条假任务（污染任务列表 / backfill 生成实例），
/// 要么破坏外键。所以这里复用的是**同一条通知通道 + 同一套权限模型**
/// （`AppNotifications`，与闹钟同用 POST_NOTIFICATIONS / 同渠道语义），
/// 而不是复用 `AlarmService` 的响铃栈。要真正合并，需要给闹钟链路加"来源"维度，
/// 那属于改 T10–T19 已验收的原生契约，本轮没动。
class BirthdayReminders {
  const BirthdayReminders._();

  /// 提醒时刻：生日当天（或提前 N 天）的 **09:00**。
  static DateTime? reminderTimeFor(BirthdayOccurrence occ, int advanceDays) {
    final base = DateTime(
      occ.nextDate.year,
      occ.nextDate.month,
      occ.nextDate.day,
      9,
    ).subtract(Duration(days: advanceDays < 0 ? 0 : advanceDays));
    return base.isAfter(DateTime.now()) ? base : null;
  }

  static String bodyFor(BirthdayOccurrence occ, int advanceDays) {
    final who = occ.birthday.name;
    if (occ.daysUntil == 0) return '今天是 $who 的生日（${occ.dateLabel}）';
    if (occ.daysUntil == 1) return '明天是 $who 的生日（${occ.dateLabel}）';
    return '$who 的生日（${occ.dateLabel}）还有 ${occ.daysUntil} 天';
  }

  /// 单条重排（保存/修改后调用；先取消旧的，避免改完后仍推旧提醒）。
  static Future<void> syncOne(Birthday birthday) async {
    final id = AppNotifications.birthdayIdBase + birthday.id;
    await AppNotifications.cancel(id);

    final occ = nextBirthdayOf(birthday, DateTime.now());
    if (occ == null) return;
    final when = reminderTimeFor(occ, birthday.advanceDays);
    if (when == null) return;

    await AppNotifications.scheduleAt(
      id: id,
      title: '生日提醒',
      body: bodyFor(occ, birthday.advanceDays),
      when: when,
    );
  }

  /// 全量重排（应用启动时调用）：保证「改系统时间 / 跨年」后提醒仍然对。
  static Future<void> syncAll(List<Birthday> birthdays) async {
    for (final b in birthdays) {
      await syncOne(b);
    }
  }
}

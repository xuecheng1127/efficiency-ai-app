import 'package:efficiency_app/features/alarm/domain/scheduled_alarm.dart';
import 'package:flutter_test/flutter_test.dart';

/// T11 · 「已经过去的一次性闹钟」判定（纯逻辑）。
///
/// 这条规则**两侧都要有**，而且必须同规则：
/// - 原生 `AlarmScheduler.isExpiredOnce`：过去的时刻交给 `setExactAndAllowWhileIdle`
///   会**立刻触发**，所以重建时必须跳过；
/// - Dart `ScheduledAlarm.isExpiredOnce`：这类记录再也不可能触发，要清理掉。
///
/// 两边一旦不一致，就会出现「原生不重排、Dart 还当它是有效闹钟」这种半吊子状态，
/// 所以这里把边界（尤其是「正好相等」）钉死。原生侧的对应实现见
/// `AlarmScheduler.kt` 的 `isExpiredOnce`，结构契约由
/// `test/features/alarm/boot_rebuild_contract_test.dart` 守。
void main() {
  ScheduledAlarm alarm({
    required int hour,
    required int minute,
    String repeatRule = 'once',
    List<int> weekdays = const [],
    DateTime? scheduledDate,
  }) =>
      ScheduledAlarm(
        id: 1,
        taskId: 1,
        hour: hour,
        minute: minute,
        repeatRule: repeatRule,
        weekdays: weekdays,
        scheduledDate: scheduledDate,
      );

  group('T11 过期一次性闹钟判定（E1–E4）', () {
    final now = DateTime(2026, 10, 16, 12, 0);

    test('E1: once 的触发时刻已经过去 —— 过期', () {
      final a = alarm(hour: 7, minute: 0, scheduledDate: DateTime(2026, 10, 15));
      expect(a.nextTriggerAt(now), DateTime(2026, 10, 15, 7, 0));
      expect(a.isExpiredOnce(now), isTrue);
    });

    test('E2: once 的触发时刻还没到 —— 未过期', () {
      final a = alarm(hour: 23, minute: 30, scheduledDate: DateTime(2026, 10, 16));
      expect(a.nextTriggerAt(now), DateTime(2026, 10, 16, 23, 30));
      expect(a.isExpiredOnce(now), isFalse);
    });

    test('E3: 触发时刻正好等于 now —— 判为过期（两侧都用 <=）', () {
      final a = alarm(hour: 12, minute: 0, scheduledDate: DateTime(2026, 10, 16));
      expect(a.nextTriggerAt(now), now);
      expect(
        a.isExpiredOnce(now),
        isTrue,
        reason: '原生是 nextTriggerMillis <= now，Dart 必须是同一侧，否则两边判断会打架',
      );
    });

    test('E4: daily / weekly 永远不会过期（nextTriggerAt 只给未来时刻）', () {
      // daily：今天已过点 → 顺延到明天
      expect(
        alarm(hour: 7, minute: 0, repeatRule: 'daily').nextTriggerAt(now),
        DateTime(2026, 10, 17, 7, 0),
      );
      expect(alarm(hour: 7, minute: 0, repeatRule: 'daily').isExpiredOnce(now), isFalse);

      // daily：今天还没到 → 今天
      expect(
        alarm(hour: 23, minute: 0, repeatRule: 'daily').nextTriggerAt(now),
        DateTime(2026, 10, 16, 23, 0),
      );
      expect(alarm(hour: 23, minute: 0, repeatRule: 'daily').isExpiredOnce(now), isFalse);

      // weekly：命中今天但已过点 → 下同星期
      expect(
        alarm(hour: 7, minute: 0, repeatRule: 'weekly', weekdays: [now.weekday])
            .isExpiredOnce(now),
        isFalse,
      );
      // weekly：七天全选 → 永远有未来的一次
      expect(
        alarm(
          hour: 0,
          minute: 0,
          repeatRule: 'weekly',
          weekdays: const [1, 2, 3, 4, 5, 6, 7],
        ).isExpiredOnce(now),
        isFalse,
      );
    });
  });
}

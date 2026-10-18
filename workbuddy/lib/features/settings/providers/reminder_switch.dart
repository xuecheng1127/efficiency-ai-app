import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/alarm_channel.dart';
import '../../../core/settings/app_settings.dart';
import '../../alarm/providers/alarm_providers.dart';

/// ============================================================================
/// 「任务提醒总开关」的真实实现
/// ============================================================================
///
/// 这是 UI 验收标准 **R1（禁止假控件）** 直接点名的那一处：
/// 之前那个开关是「硬编码开 + 空回调」，用户点了以为闹钟关了、其实什么都没发生。
///
/// ## 关闭 / 开启分别做什么
///
/// | 动作 | 副作用 |
/// |---|---|
/// | 关闭 | ① `scheduled_alarms.enabled` 全置 0；② 逐个调 native `cancel` 立刻撤掉系统侧已排的闹钟 |
/// | 开启 | ① `enabled` 全置 1；② `rescheduleAll()` 按表全量重排 |
///
/// **顺序很重要**：先落库（②在后），因为原生 `rescheduleAll` / 开机重建都**只认
/// `enabled = 1` 的行**。先落库就堵死了「中途被重排回来」的窗口。
///
/// ## 关闭期间"新建闹钟"怎么办
/// `scheduleForTask` 插入的新行默认 `enabled = true`，所以兜底不在本类里，而在
/// `AlarmEditorDialog._save()`：保存后若总开关为关，会把该行打回 0 并撤掉刚排上的系统闹钟。
/// （这条兜底是 UI 打磨阶段补的 —— 之前只有注释、没有实现，评审方审查时点出了这个漏洞。）
class ReminderSwitch {
  ReminderSwitch(this.ref);

  final Ref ref;

  /// 关闭/开启全局提醒。返回是否成功（失败时页面应提示，不能"点了没反应也没提示"）。
  Future<bool> setEnabled(bool enabled) async {
    try {
      // ① 先落库（真源）
      await ref.read(alarmRepositoryProvider).setAllEnabled(enabled);

      if (!enabled) {
        // ② 再撤掉系统侧已经排好的闹钟（读的是落库前的快照，所以放在 setAllEnabled 之后取）
        final alarms = await ref.read(alarmRepositoryProvider).loadAll();
        for (final alarm in alarms) {
          try {
            await AlarmScheduler.cancel(alarm.taskId);
          } catch (_) {
            // 单个取消失败不阻断其它：数据库已经是 enabled=0，开机重建不会把它带回来
          }
        }
      } else {
        // ② 全量重排
        await AlarmScheduler.rescheduleAll();
      }

      await ref
          .read(appSettingsProvider.notifier)
          .patch(remindersEnabled: enabled);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final reminderSwitchProvider = Provider<ReminderSwitch>(ReminderSwitch.new);

/// 闹钟档位（PRD v2 §3.3 的三档降级）。
///
/// T10 只负责「能存能读」，档位的判定与重排属于 T12；
/// 此枚举定义了 `scheduled_alarms.tier` 的取值集合，避免下游各写一套字符串。
enum AlarmTier {
  /// A 精确档：`setExactAndAllowWhileIdle`（需精确闹钟权限）
  exact,

  /// B 近似档：`setWindow(60s)` + 周期扫描兜底（国产 ROM 深省电下的保险）
  inexact,

  /// C 应用内档：仅应用在前台时提醒（兜底）
  inApp;

  /// 解析数据库里的字符串；未知值降级为 [AlarmTier.inexact]（不抛异常，避免脏数据炸 UI）。
  static AlarmTier parse(String? raw) {
    for (final t in AlarmTier.values) {
      if (t.name == raw) return t;
    }
    return AlarmTier.inexact;
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ============================================================================
/// 「今天是哪天」的全局节拍
/// ============================================================================
///
/// 为什么要有这一层：`DateTime.now()` 只在你调用它的那一刻是正确的。
/// 应用挂在后台过夜、或者干脆没关，所有「初始化时算好的一天」都会变成昨天：
/// - 火花会把「今天没做」算成「昨天没做」；
/// - 任务页会继续显示昨天的实例，用户点完成就写到昨天的记录上。
///
/// 这里用一条**到次日零点自动醒来**的流给出「今天」，跨日时下游全部重算。
/// 跨零点的时间点是算出来的（`nextMidnightAfter`），不是每 60 秒轮询一次 ——
/// 轮询会在整点附近抖，也会在长时间挂起时漂移。

/// 下一次零点（多给 1 秒余量，避免醒来时还停在 23:59:59.999）。
DateTime nextMidnightAfter(DateTime now) {
  final next = DateTime(now.year, now.month, now.day + 1);
  return next.add(const Duration(seconds: 1));
}

/// 把时间归一化到本地日期的零点（按日历构造，避免 DST 的 23/25 小时问题）。
DateTime dayOnly(DateTime t) => DateTime(t.year, t.month, t.day);

/// 「今天」流：先吐当天，然后睡到次日零点再吐。
///
/// [clock] 只为测试注入；生产用 `DateTime.now`。
Stream<DateTime> dayTickStream({DateTime Function() clock = DateTime.now}) async* {
  while (true) {
    final now = clock();
    yield dayOnly(now);
    final wakeAt = nextMidnightAfter(now);
    final wait = wakeAt.difference(now);
    // 时钟被回拨 / 计算异常时不要退化成「0 秒死循环」。
    await Future<void>.delayed(wait.isNegative ? const Duration(minutes: 1) : wait);
  }
}

final dayTickProvider = StreamProvider<DateTime>((ref) => dayTickStream());

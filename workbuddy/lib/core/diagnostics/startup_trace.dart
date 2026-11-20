import 'package:flutter/foundation.dart';

/// 启动耗时打点（R5 任务 1）。
///
/// 为什么不用 `Timeline`：`am start -W` 给的是「系统视角的总时间」，
/// 而我们需要知道**这 1000ms 花在 Dart 侧哪一段**。`Timeline` 在 release
/// 包里要接 observatory 才能看，这里用一行行 logcat 更直接：
///
/// ```
/// adb logcat -s flutter | grep STARTUP
/// ```
///
/// 输出形如：
/// `[STARTUP] boot.db.open +312ms total=520ms`（`+` 是与上一打点的间隔）。
///
/// 只在 `kStartupTrace` 为真时输出，出正式包时置 false 即可零成本。
const bool kStartupTrace = true;

class StartupTrace {
  StartupTrace._();

  /// 进程内第一条打点即为 t0（`main()` 第一行）。
  static final Stopwatch _sw = Stopwatch()..start();
  static int _last = 0;
  static bool _enabled = true;

  /// 关闭后续打点（测完或不想刷 logcat 时用）。
  static void disable() => _enabled = false;

  static int get elapsedMs => _sw.elapsedMilliseconds;

  static void mark(String label) {
    if (!kStartupTrace || !_enabled) return;
    final total = _sw.elapsedMilliseconds;
    final delta = total - _last;
    _last = total;
    debugPrint('[STARTUP] $label +${delta}ms total=${total}ms');
  }

  /// 一次性打点：同一 label 只输出一次（首帧/首屏数据这类可能被多次触发的位置）。
  static final Set<String> _once = <String>{};

  static void markOnce(String label) {
    if (_once.contains(label)) return;
    _once.add(label);
    mark(label);
  }
}

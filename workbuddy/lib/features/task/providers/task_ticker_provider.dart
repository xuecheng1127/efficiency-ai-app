import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 秒级时钟（**只服务「计时中」的条目**）。
///
/// 背景（P0-3）：此前耗时只在 `build` 里用 `DateTime.now() - startedAt` 算一次，
/// 界面进入后不再重建，于是「点一下变蓝，之后再也不动」，秒数永远停在进入那一刻。
///
/// 做法：暴露一个每秒发一次的流，`TaskTile` 在 `inProgress` 时 watch 它，
/// 从而每秒重建一次 —— 只有渲染，不碰数据库（计时真源仍是 `startedAt`）。
///
/// 为什么 `autoDispose`：没有计时中的任务时没有任何订阅者，provider 自动释放，
/// 定时器跟着停掉，不会在后台空转一秒一跳。
final taskTickerProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return _ticks();
});

/// 立刻给一个当前时刻（避免首帧空一撮），之后每秒一跳。
Stream<DateTime> _ticks() async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 主页底部导航的当前页索引。
///
/// 为什么从 `HomePage` 的 `setState` 提到 Provider 里：
/// 全局搜索是一个**压在主界面之上的独立页面**，搜到任务后要「回到任务页」，
/// 这一步必须改主页的 tab —— 页面拿不到 `_HomePageState`，只能共享状态。
/// 顺手也把「首页索引」变成可测的纯状态。
class HomeTabNotifier extends Notifier<int> {
  /// 0 工作台 / 1 任务 / 2 工具箱 / 3 设置
  static const int count = 4;

  @override
  int build() => 0;

  void select(int index) {
    if (index < 0 || index >= count) return;
    state = index;
  }
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(
  HomeTabNotifier.new,
);

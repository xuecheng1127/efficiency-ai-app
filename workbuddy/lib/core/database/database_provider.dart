import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// ============================================================================
/// 数据库实例 Provider（可在「从备份恢复」时**整体替换**）
/// ============================================================================
///
/// 为什么不是 `Provider<AppDatabase>` + `overrideWithValue`：
/// override 的值在整个 `ProviderScope` 生命周期里是常量，恢复完新库后
/// 拿不到「把它换成新实例」的口子 —— 全应用还握着那个已经 close 掉的旧连接，
/// 于是恢复成功、界面却全部报错。
///
/// 改成 `NotifierProvider` 后：
/// - 消费方代码**一行都不用改**（`ref.watch(databaseProvider)` 依然返回 `AppDatabase`）；
/// - 恢复成功时 [replace] 一调，所有 watch 它的仓库 / 流全部重建并重新订阅，
///   界面自然切换到恢复后的数据；
/// - 旧实例由恢复流程显式 `close()`，不留悬挂连接。
class DatabaseNotifier extends Notifier<AppDatabase> {
  DatabaseNotifier([this._seed]);

  /// 启动时注入的实例（`ProviderScope(overrides: [...])` 走这个）。
  final AppDatabase? _seed;

  @override
  AppDatabase build() {
    final seed = _seed;
    if (seed == null) {
      throw UnimplementedError('数据库实例需在 ProviderScope.overrides 中注入');
    }
    return seed;
  }

  /// 换到新实例（「从备份恢复」成功后调用）。
  void replace(AppDatabase db) {
    state = db;
  }
}

final databaseProvider = NotifierProvider<DatabaseNotifier, AppDatabase>(
  DatabaseNotifier.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// 数据库实例 Provider（T01 规格 §10.3）
///
/// 全局唯一数据库访问入口。初始化在启动页完成（SplashPage 调用
/// [AppDatabase.instance] 触发懒打开），此后各层通过此 Provider 获取实例。
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

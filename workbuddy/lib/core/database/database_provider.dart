import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// 数据库实例 Provider。
///
/// 在 [main] 中通过 `overrideWithValue` 注入真实实例，
/// 此处直接抛错以保证「未初始化即使用」在开发期立刻暴露。
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('数据库实例需在 main() 中注入'),
);

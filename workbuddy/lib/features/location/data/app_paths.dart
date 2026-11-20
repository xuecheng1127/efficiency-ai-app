import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// ============================================================================
/// 应用私有路径解析（**先不依赖插件**，再退到 path_provider）
/// ============================================================================
///
/// 为什么单独抽出来：同一条路径要在两个 isolate 里各自解析出来 ——
/// UI 侧（插件齐全）和前台服务的后台 isolate（R4B 之前那里**一个原生插件都没注册**）。
///
/// 顺序（每一级都必须能独立跑通）：
/// 1. 进程内缓存（同一 isolate 只算一次）；
/// 2. **纯 dart:io 推算**：`Directory.systemTemp` 在 Android 上是
///    `/data/user/0/<pkg>/cache`，父目录 + `/app_flutter` 正是
///    `getApplicationDocumentsDirectory()`（path_provider 的 Kotlin 实现就是
///    `context.getDir("flutter", MODE_PRIVATE)`）；
/// 3. 最后才问 path_provider（需要插件通道）。
///
/// 上一版把「prefs 里缓存的路径」放在第 1 级，结果 prefs 通道一坏，
/// 整条解析链的第一环就先抛异常 —— 现在这里**没有任何插件依赖**。
class AppPaths {
  AppPaths._();

  static const String dbFileName = 'efficiency_app.sqlite';

  /// 围栏运行期状态（在内/在外、上次提醒、暂停标记）。
  static const String geofenceStateFileName = 'geofence_state.json';

  static String? _memDbPath;

  /// 记下已经解析成功的路径（跨调用省一次 stat）。
  static void rememberDbPath(String path) => _memDbPath = path;

  @visibleForTesting
  static void forgetDbPath() => _memDbPath = null;

  /// 数据库文件绝对路径；解析不出来返回 null（调用方按「这一拍没数据」处理）。
  static Future<String?> dbPath() async {
    final cached = _memDbPath;
    if (cached != null && File(cached).existsSync()) return cached;

    final derived = _fromSystemTemp();
    if (derived != null) {
      _memDbPath = derived;
      debugPrint('[paths] db via systemTemp: $derived');
      return derived;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = p.join(dir.path, dbFileName);
      if (File(path).existsSync()) {
        _memDbPath = path;
        debugPrint('[paths] db via path_provider: $path');
        return path;
      }
      debugPrint('[paths] path_provider dir has no db: $path');
    } catch (e) {
      debugPrint('[paths] path_provider unavailable: $e');
    }

    // 文件暂时不存在（首次启动尚未建库）也先认缓存值，交给调用方去 open 失败
    if (cached != null) {
      _memDbPath = cached;
      return cached;
    }
    return null;
  }

  /// 数据目录（= 数据库所在目录）。
  static Future<String?> dataDir() async {
    final db = await dbPath();
    return db == null ? null : p.dirname(db);
  }

  /// 围栏状态文件（与数据库同目录，两个 isolate 看到的是同一个文件）。
  static Future<File?> geofenceStateFile() async {
    final dir = await dataDir();
    if (dir == null) return null;
    return File(p.join(dir, geofenceStateFileName));
  }

  /// 纯 dart:io 推算（Android 专属，其它平台返回 null）。
  static String? _fromSystemTemp() {
    if (!Platform.isAndroid) return null;
    try {
      final tmp = Directory.systemTemp;
      final candidates = <String>[
        // .../cache → .../app_flutter（正常情况）
        p.join(tmp.parent.path, 'app_flutter', dbFileName),
        // 少数机型 TMPDIR 直接指向 files 目录
        p.join(tmp.path, 'app_flutter', dbFileName),
        p.join(tmp.path, dbFileName),
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) return path;
      }
    } catch (_) {}
    return null;
  }
}

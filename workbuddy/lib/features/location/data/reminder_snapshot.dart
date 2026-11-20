import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/location_reminder.dart';
import 'app_paths.dart';

/// ============================================================================
/// 后台读库：**不打开 AppDatabase，只跑一条 SELECT**
/// ============================================================================
///
/// 为什么不用 `AppDatabase` / 仓库：
/// - 后台 isolate 里没有 `ProviderScope`，`databaseProvider` 根本不存在；
/// - `AppDatabase` 打开时会跑迁移与 `beforeOpen` 里的 PRAGMA，那是「写库」行为，
///   而我们的后台任务只该读。用 `NativeDatabase` 直接执行一条 SELECT，
///   连 schema 版本都不会碰。
///
/// 表结构是稳定契约（`location_reminders`，v8 起没有变过），列名用 drift 的
/// 默认蛇形命名。`deleted_at IS NULL AND enabled = 1` 就是「启用中」。
class ReminderSnapshot {
  const ReminderSnapshot();

  static const String dbFileName = AppPaths.dbFileName;

  /// 这些列必须与 `location_reminders` 表一致；`parseRows` 只认这套键名。
  static const String selectSql = '''
SELECT id, title, place_name, latitude, longitude, radius_meters,
       trigger_on, enabled, notified_at, created_at, deleted_at
FROM location_reminders
WHERE deleted_at IS NULL AND enabled = 1
ORDER BY id''';

  /// 定位数据库文件。
  ///
  /// 解析顺序与兜底全部集中在 [AppPaths]（**不依赖任何插件通道**）：
  /// 进程内缓存 → `Directory.systemTemp` 推算 → path_provider。
  ///
  /// 为什么不允许第一环就碰插件：R4B 之前第一环是「prefs 里缓存的路径」，
  /// 而 prefs 在后台 isolate 里整条通道都不存在（channel-error），
  /// 于是一次读库失败 → 服务以为「没有围栏」→ 自停。
  Future<String?> resolveDbPath() => AppPaths.dbPath();

  /// 读「启用中的途径提醒」。
  ///
  /// 返回 `null` 表示**读失败**，`[]` 表示**真的没有启用中的提醒**。
  /// 这两者对调用方意义完全不同：前者只能等下一拍，后者应该停掉服务。
  /// 早期版本把两者混成 `[]`，于是「一次读库失败」= 「服务自杀」。
  Future<List<LocationReminder>?> readEnabled() async {
    final path = await resolveDbPath();
    if (path == null) {
      debugPrint('[geofence] no db path, skip this pulse');
      return null;
    }

    // 用 package:sqlite3 直接开，不用 drift 的 NativeDatabase。
    // 实测（v1.6 第一次装机）：drift 的 NativeDatabase 在**服务引擎**里
    // `runSelect` 会抛 `Null check operator used on a null value` —— 它假定
    // 自己被 drift 的运行时初始化过（AppDatabase / 后台 isolate 的 zone），
    // 而这个 isolate 只执行一个回调，没有那些前提。sqlite3 是纯 FFI，无此问题。
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
    } catch (e) {
      debugPrint('[geofence] readOnly open failed, retry readWrite: $e');
      try {
        db = sqlite3.open(path);
      } catch (e2) {
        debugPrint('[geofence] open db failed: $e2');
        return null;
      }
    }

    try {
      final rows = db.select(selectSql);
      final parsed = parseRows([
        for (final row in rows) Map<String, Object?>.from(row),
      ]);
      if (parsed.length != rows.length) {
        debugPrint(
          '[geofence] ${rows.length - parsed.length} row(s) skipped while parsing',
        );
      }
      return parsed;
    } catch (e) {
      debugPrint('[geofence] read reminders failed: $e');
      return null;
    } finally {
      db.close();
    }
  }

  /// 纯解析（单测直接喂 Map，不需要真库）。
  ///
  /// 兼容三处不稳定因素：
  /// - `enabled` 可能是 0/1（SQLite 原生）也可能是 bool（drift 转换后）；
  /// - 时间列 drift 默认存 **Unix 秒**，但历史备份导入可能是 ISO 字符串；
  /// - `trigger_on` 可能为 null（老库补列）。
  static List<LocationReminder> parseRows(List<Map<String, Object?>> rows) {
    final result = <LocationReminder>[];
    for (final row in rows) {
      final id = _asInt(row['id']);
      final latitude = _asDouble(row['latitude']);
      final longitude = _asDouble(row['longitude']);
      if (id == null || latitude == null || longitude == null) continue;

      final radius = _asInt(row['radius_meters']) ?? 200;
      result.add(
        LocationReminder(
          id: id,
          title: (row['title'] as String?) ?? '',
          placeName: (row['place_name'] as String?) ?? '',
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radius < 50 ? 50 : radius,
          triggerOn: TriggerOn.byId(row['trigger_on'] as String?),
          enabled: _asBool(row['enabled']) ?? true,
          notifiedAt: _asTime(row['notified_at']),
          createdAt: _asTime(row['created_at']) ?? DateTime.now(),
          deletedAt: _asTime(row['deleted_at']),
        ),
      );
    }
    return result;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == '1' || v == 'true') return true;
      if (v == '0' || v == 'false') return false;
    }
    return null;
  }

  /// drift 的 `dateTime()` 默认写 Unix **秒**（`INTEGER`）。
  static DateTime? _asTime(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
          .toLocal();
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

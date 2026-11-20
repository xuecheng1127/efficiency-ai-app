import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_paths.dart';

/// ============================================================================
/// 围栏状态缓存（JSON 文件）—— 前后台两个 isolate 的唯一共享内存
/// ============================================================================
///
/// **R4B 换成文件的原因（这是 v1.6 保存卡死的根因之一）**：
/// 原来这里用 `SharedPreferences`，但它在两个 isolate 里都不可靠 ——
/// release 包的 logcat 里主 isolate 和后台 isolate 都报
/// `PlatformException(channel-error, ... SharedPreferencesApi.getAll)`。
/// 后台 isolate 更彻底：服务的 `FlutterEngine` 是插件自己 new 出来的，
/// 一个原生插件都没注册（见 R4B 报告 §A1），pigeon 通道根本不存在。
///
/// 现在的存储介质是**数据库旁边的一个 JSON 文件**：
/// - 只用 `dart:io`，不经过任何 MethodChannel，两个 isolate 都能读写；
/// - 路径由 [AppPaths] 推算（同样不依赖插件）；
/// - 写入用「临时文件 + rename」，读到的要么是旧值要么是新值，不会是半截 JSON。
///
/// 为什么不写回 SQLite：本项目没开 WAL，两个连接同时写最容易撞 `SQLITE_BUSY`；
/// 更糟的是 drift 的连接池在 UI 侧，后台写会让「正在滚动列表」的那一帧读到半截。
/// 所以约定仍然是：
///
/// - 数据库 = 用户编辑的事实（提醒本身），只由 UI 侧写；
/// - 状态文件 = 运行期状态（上次在内/在外、上次提醒时间、是否被划掉通知），
///   两边都能读写，谁先跑谁写；
/// - 下次 App 回到前台时，`LocationMonitor.sync()` 会把文件里更新的
///   「上次提醒」补写回数据库，列表上的「上次提醒 3 分钟前」才不会失真。
class GeofenceStateStore {
  GeofenceStateStore({File? file}) : _fileOverride = file;

  /// 单测注入用；null = 走 [AppPaths] 真实推算。
  final File? _fileOverride;

  File? _resolvedFile;

  /// 同一 isolate 内的写入串成一条链：读-改-写不能交错，否则后写的会盖掉先写的。
  /// 静态是为了让同一 isolate 里多个 store 实例（monitor / watcher / task）也不打架。
  static Future<void> _writeChain = Future<void>.value();

  /// 进程内影子：文件读不出来时（首次运行 / 目录还没建好）仍能维持
  /// 「状态翻转才通知」的语义，只是活不过进程结束。
  static final _State _mem = _State();

  /// 单测用：清掉影子缓存，模拟「刚启动的进程」。
  @visibleForTesting
  static void resetMemoryShadow() {
    _mem.inside.clear();
    _mem.notified.clear();
    _mem.paused = false;
    _mem.lastPulseAt = null;
  }

  Future<File?> _file() async {
    if (_fileOverride != null) return _fileOverride;
    final cached = _resolvedFile;
    if (cached != null) return cached;
    try {
      final file = await AppPaths.geofenceStateFile();
      if (file != null) _resolvedFile = file;
      return file;
    } catch (e) {
      debugPrint('[geofence] state file path unavailable: $e');
      return null;
    }
  }

  /// 读全部状态。文件里的值优先；读不到才用影子缓存。
  Future<GeofenceSnapshot> load() async {
    final disk = await _readDisk();
    if (disk != null) _copy(_mem, disk);

    return GeofenceSnapshot(
      inside: Map<int, bool>.from(_mem.inside),
      notified: Map<int, DateTime>.from(_mem.notified),
      paused: _mem.paused,
      lastPulseAt: _mem.lastPulseAt,
    );
  }

  /// 一次性写回「每条围栏是否在内」。
  ///
  /// 只写**值变了**的那几条：每分钟一拍，全量写会让文件反复落盘。
  Future<void> saveInside(Map<int, bool> inside) {
    var changed = false;
    return _mutate((s) {
      for (final entry in inside.entries) {
        if (s.inside[entry.key] == entry.value) continue;
        s.inside[entry.key] = entry.value;
        changed = true;
      }
    }, skipWrite: () => !changed);
  }

  Future<void> saveNotified(int id, DateTime at) {
    return _mutate((s) => s.notified[id] = at);
  }

  Future<void> saveLastPulse(DateTime at) {
    return _mutate((s) => s.lastPulseAt = at);
  }

  /// 用户把常驻通知划掉了 = 他明确表示「别在后台盯着我」。
  ///
  /// 之后再启动服务就成了「和用户对着干」，所以暂停标记要落盘：
  /// 只有用户主动改提醒（新增 / 打开开关）才会清掉它。
  Future<bool> isPaused() async => (await load()).paused;

  Future<void> setPaused(bool value) => _mutate((s) => s.paused = value);

  /// 读-改-写。**永不抛异常**（调用方都是「尽力而为」的路径）。
  Future<void> _mutate(
    void Function(_State s) change, {
    bool Function()? skipWrite,
  }) {
    final next = _writeChain.then((_) async {
      try {
        final s = await _readDisk() ?? _clone(_mem);
        change(s);
        _copy(_mem, s);
        if (skipWrite?.call() == true) return;
        await _writeDisk(s);
      } catch (e) {
        debugPrint('[geofence] state write failed: $e');
      }
    });
    // 链上只放「已消化异常」的 future，避免一次失败把后续写入全部毒死。
    _writeChain = next;
    return next;
  }

  Future<_State?> _readDisk() async {
    final file = await _file();
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      return _parse(text);
    } catch (e) {
      // 半截 JSON / 权限问题：退回影子缓存，下次写入会覆盖掉坏文件
      debugPrint('[geofence] state read failed: $e');
      return null;
    }
  }

  Future<void> _writeDisk(_State s) async {
    final file = await _file();
    if (file == null) return;
    final payload = _encode(s);
    final tmp = File('${file.path}.tmp');
    try {
      await tmp.writeAsString(payload, flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      // rename 在个别平台/文件系统上会失败：直接写目标文件兜底
      debugPrint('[geofence] state rename failed, direct write: $e');
      await file.writeAsString(payload, flush: true);
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  static String _encode(_State s) => jsonEncode({
    'version': 1,
    'inside': {for (final e in s.inside.entries) '${e.key}': e.value},
    'notified': {
      for (final e in s.notified.entries) '${e.key}': e.value.millisecondsSinceEpoch,
    },
    'paused': s.paused,
    'lastPulseAt': s.lastPulseAt?.millisecondsSinceEpoch,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  });

  static _State _parse(String text) {
    final s = _State();
    final decoded = jsonDecode(text);
    if (decoded is! Map) return s;

    final inside = decoded['inside'];
    if (inside is Map) {
      inside.forEach((key, value) {
        final id = int.tryParse('$key');
        if (id == null) return;
        final flag = _asBool(value);
        if (flag != null) s.inside[id] = flag;
      });
    }

    final notified = decoded['notified'];
    if (notified is Map) {
      notified.forEach((key, value) {
        final id = int.tryParse('$key');
        if (id == null) return;
        final at = _asTime(value);
        if (at != null) s.notified[id] = at;
      });
    }

    s.paused = _asBool(decoded['paused']) ?? false;
    s.lastPulseAt = _asTime(decoded['lastPulseAt']);
    return s;
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

  static DateTime? _asTime(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static _State _clone(_State s) => _State()
    ..inside.addAll(s.inside)
    ..notified.addAll(s.notified)
    ..paused = s.paused
    ..lastPulseAt = s.lastPulseAt;

  static void _copy(_State dst, _State src) {
    dst.inside
      ..clear()
      ..addAll(src.inside);
    dst.notified
      ..clear()
      ..addAll(src.notified);
    dst.paused = src.paused;
    dst.lastPulseAt = src.lastPulseAt;
  }
}

class _State {
  final Map<int, bool> inside = {};
  final Map<int, DateTime> notified = {};
  bool paused = false;
  DateTime? lastPulseAt;
}

/// 一份状态快照。
class GeofenceSnapshot {
  const GeofenceSnapshot({
    required this.inside,
    required this.notified,
    required this.paused,
    this.lastPulseAt,
  });

  final Map<int, bool> inside;
  final Map<int, DateTime> notified;
  final bool paused;
  final DateTime? lastPulseAt;

  static const GeofenceSnapshot empty = GeofenceSnapshot(
    inside: {},
    notified: {},
    paused: false,
  );
}

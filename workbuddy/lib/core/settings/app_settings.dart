import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// ============================================================================
/// 全局设置（可持久化）
/// ============================================================================
///
/// 为什么自己写：本工程**没有** `shared_preferences` 依赖，也**没有** `AppSetting` 表。
/// 设置页要满足 R1（禁止假控件），就必须真的存下来 —— 而为了 6 个键引入一个插件
/// 不划算，所以用已有的 `path_provider` 写一个小 JSON 文件。
///
/// 存的位置：`getApplicationSupportDirectory()/app_settings.json`
/// （应用私有目录，卸载即清，不进备份、不需要权限）。
class AppSettings {
  const AppSettings({
    this.remindersEnabled = true,
    this.snoozeEnabled = true,
    this.snoozeMinutes = 5,
    this.ringtone = kDefaultRingtone,
    this.volume = 80,
    this.defaultRepeatMode = 'daily',
    this.themeMode = 'system',
    this.workbenchModules = const <String>[],
    this.calorieTarget = 2000,
    this.calorieSex = 'male',
    this.calorieAge = 30,
    this.calorieHeightCm = 170,
    this.calorieWeightKg = 65,
    this.calorieActivity = 1.375,
    this.longestStreak = 0,
  });

  /// 内置铃音（原生侧 `AlarmService` 按名字匹配同名前缀的资源）。
  static const String kDefaultRingtone = '风铃轻响';

  /// 可选铃音（与 `AlarmEditorDialog` 里的列表保持一致）。
  static const List<String> kRingtones = ['风铃轻响', '晨光微露', '静水流深'];

  /// 任务提醒总开关：关闭后**全部**闹钟不响（见 `reminder_switch.dart`）。
  final bool remindersEnabled;

  /// 贪睡模式开关。
  final bool snoozeEnabled;

  /// 贪睡间隔（分钟）。
  final int snoozeMinutes;

  /// 闹钟铃音名。
  final String ringtone;

  /// 闹钟音量（0–100）。
  final int volume;

  /// 新任务默认重复规则（`once` / `daily` / `weekly`）。
  final String defaultRepeatMode;

  /// 主题模式（`system` / `light` / `dark`）。
  final String themeMode;

  /// 工作台要显示的模块 id 列表（`tasks` / `diary`）。
  ///
  /// **空列表 = 还没配置**（不是"配置成什么都不显示"）：工作台据此显示空态，
  /// 并给出预设模式让用户一键起步（见 `workbench_module.dart`）。
  final List<String> workbenchModules;

  /// 每日热量目标（kcal）。由「目标设置」按 Mifflin-St Jeor 算出后可手改。
  final int calorieTarget;

  /// 计算目标用的身体数据（存下来是为了下次打开能回显、能重算）。
  final String calorieSex; // male | female
  final int calorieAge;
  final int calorieHeightCm;
  final int calorieWeightKg;
  final double calorieActivity;

  /// 历史最长连续火花天数（缓存）。
  ///
  /// 为什么要有这个缓存：火花本身是从 `task_instances.completed_at` 现算的，
  /// 但「历史最长」一旦被打破就应当保留 —— 如果只靠当前数据算，
  /// 用户哪天把旧任务删了，历史最长会跟着缩水。这里存的是**只增不减**的下界，
  /// 展示时取 `max(现算值, 缓存值)`。
  final int longestStreak;

  AppSettings copyWith({
    bool? remindersEnabled,
    bool? snoozeEnabled,
    int? snoozeMinutes,
    String? ringtone,
    int? volume,
    String? defaultRepeatMode,
    String? themeMode,
    List<String>? workbenchModules,
    int? calorieTarget,
    String? calorieSex,
    int? calorieAge,
    int? calorieHeightCm,
    int? calorieWeightKg,
    double? calorieActivity,
    int? longestStreak,
  }) {
    return AppSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      ringtone: ringtone ?? this.ringtone,
      volume: volume ?? this.volume,
      defaultRepeatMode: defaultRepeatMode ?? this.defaultRepeatMode,
      themeMode: themeMode ?? this.themeMode,
      workbenchModules: workbenchModules ?? this.workbenchModules,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      calorieSex: calorieSex ?? this.calorieSex,
      calorieAge: calorieAge ?? this.calorieAge,
      calorieHeightCm: calorieHeightCm ?? this.calorieHeightCm,
      calorieWeightKg: calorieWeightKg ?? this.calorieWeightKg,
      calorieActivity: calorieActivity ?? this.calorieActivity,
      longestStreak: longestStreak ?? this.longestStreak,
    );
  }

  Map<String, Object?> toJson() => {
    'remindersEnabled': remindersEnabled,
    'snoozeEnabled': snoozeEnabled,
    'snoozeMinutes': snoozeMinutes,
    'ringtone': ringtone,
    'volume': volume,
    'defaultRepeatMode': defaultRepeatMode,
    'themeMode': themeMode,
    'workbenchModules': workbenchModules,
    'calorieTarget': calorieTarget,
    'calorieSex': calorieSex,
    'calorieAge': calorieAge,
    'calorieHeightCm': calorieHeightCm,
    'calorieWeightKg': calorieWeightKg,
    'calorieActivity': calorieActivity,
    'longestStreak': longestStreak,
  };

  /// 容错解析：**任何**字段坏掉都退回默认值，绝不让设置文件把应用启动搞崩。
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const fallback = AppSettings();
    T pick<T>(String key, T def) {
      final v = json[key];
      return v is T ? v : def;
    }

    return AppSettings(
      remindersEnabled: pick('remindersEnabled', fallback.remindersEnabled),
      snoozeEnabled: pick('snoozeEnabled', fallback.snoozeEnabled),
      snoozeMinutes: pick('snoozeMinutes', fallback.snoozeMinutes),
      ringtone: pick('ringtone', fallback.ringtone),
      volume: pick('volume', fallback.volume),
      defaultRepeatMode: pick('defaultRepeatMode', fallback.defaultRepeatMode),
      themeMode: pick('themeMode', fallback.themeMode),
      workbenchModules: _parseStringList(json['workbenchModules']),
      calorieTarget: pick('calorieTarget', fallback.calorieTarget),
      calorieSex: pick('calorieSex', fallback.calorieSex),
      calorieAge: pick('calorieAge', fallback.calorieAge),
      calorieHeightCm: pick('calorieHeightCm', fallback.calorieHeightCm),
      calorieWeightKg: pick('calorieWeightKg', fallback.calorieWeightKg),
      // JSON 里的 1.55 是 double，但 1.0 可能被编码成 1（int）—— 两种都要收
      calorieActivity: _parseDouble(
        json['calorieActivity'],
        fallback.calorieActivity,
      ),
      longestStreak: _parseNonNegativeInt(
        json['longestStreak'],
        fallback.longestStreak,
      ),
    );
  }

  static double _parseDouble(Object? raw, double fallback) {
    if (raw is num) {
      final v = raw.toDouble();
      if (v >= 1.0 && v <= 3.0) return v;
    }
    return fallback;
  }

  /// 非负整数（火花缓存用）：负数 / 字符串 / null 一律退回默认值。
  static int _parseNonNegativeInt(Object? raw, int fallback) {
    if (raw is int && raw >= 0) return raw;
    return fallback;
  }

  /// 只收 `List<String>`：混进数字/null 就跳过，整个字段坏掉就退回空列表。
  static List<String> _parseStringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return [
      for (final v in raw)
        if (v is String && v.isNotEmpty) v,
    ];
  }
}

/// JSON 文件读写（同步读、异步写 —— 启动时只读一次，改动时才写）。
class SettingsStore {
  SettingsStore(this.file);

  final File file;

  /// 打开默认位置的设置文件（目录不存在会自动创建）。
  static Future<SettingsStore> open() async {
    final dir = await getApplicationSupportDirectory();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return SettingsStore(File(p.join(dir.path, 'app_settings.json')));
  }

  /// 读设置。文件不存在 / 解析失败 → 全部退回默认值（并保留坏文件以便排查）。
  AppSettings load() {
    if (!file.existsSync()) return const AppSettings();
    try {
      final text = file.readAsStringSync();
      if (text.trim().isEmpty) return const AppSettings();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, Object?>) return const AppSettings();
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// 写设置（`flush: true`，避免进程被杀时丢最后一次改动）。
  Future<void> save(AppSettings settings) async {
    try {
      if (!file.parent.existsSync()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(settings.toJson()),
        flush: true,
      );
    } catch (_) {
      // 写失败不抛给 UI：设置属于"尽力持久化"，不该把页面搞崩。
    }
  }
}

/// 设置存储（在 `main()` 里 override，保证同步可用）。
final settingsStoreProvider = Provider<SettingsStore>((ref) {
  throw UnimplementedError(
    'settingsStoreProvider 必须在 ProviderScope.overrides 中注入',
  );
});

/// 启动时读到的初始设置（避免首帧闪一下默认值）。
final initialSettingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsStoreProvider).load();
});

/// 当前设置（响应式）。改动会立刻落盘。
class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  SettingsStore get _store => ref.read(settingsStoreProvider);

  /// 更新并持久化。返回更新后的值，便于调用方接着做副作用。
  Future<AppSettings> update(AppSettings next) async {
    state = next;
    await _store.save(next);
    return next;
  }

  /// 局部更新。
  Future<AppSettings> patch({
    bool? remindersEnabled,
    bool? snoozeEnabled,
    int? snoozeMinutes,
    String? ringtone,
    int? volume,
    String? defaultRepeatMode,
    String? themeMode,
    List<String>? workbenchModules,
    int? calorieTarget,
    String? calorieSex,
    int? calorieAge,
    int? calorieHeightCm,
    int? calorieWeightKg,
    double? calorieActivity,
    int? longestStreak,
  }) {
    return update(
      state.copyWith(
        remindersEnabled: remindersEnabled,
        snoozeEnabled: snoozeEnabled,
        snoozeMinutes: snoozeMinutes,
        ringtone: ringtone,
        volume: volume,
        defaultRepeatMode: defaultRepeatMode,
        themeMode: themeMode,
        workbenchModules: workbenchModules,
        calorieTarget: calorieTarget,
        calorieSex: calorieSex,
        calorieAge: calorieAge,
        calorieHeightCm: calorieHeightCm,
        calorieWeightKg: calorieWeightKg,
        calorieActivity: calorieActivity,
        longestStreak: longestStreak,
      ),
    );
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/birthdays_table.dart';
import 'tables/calorie_entries_table.dart';
import 'tables/diaries_table.dart';
import 'tables/location_reminders_table.dart';
import 'tables/memos_table.dart';
import 'tables/scheduled_alarms.dart';
import 'tables/shopping_items_table.dart';
import 'tables/task_instances.dart';
import 'tables/task_templates.dart';

part 'app_database.g.dart';

/// Drift 数据库（任务三层结构 + 闹钟 + 日记 + 备忘录 + 工具箱插件表）。
@DriftDatabase(
  tables: [
    TaskTemplates,
    TaskInstances,
    ScheduledAlarms,
    Diaries,
    Memos,
    ShoppingItems,
    Birthdays,
    CalorieEntries,
    LocationReminders,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 版本历史：
  /// - 1：单表 `tasks`
  /// - 2：双层模型 `task_templates` + `task_instances`（T01）
  /// - 3：新增 `scheduled_alarms`（T10 闹钟持久化）
  /// - 4：新增 `diaries`（T22 日记）+ `memos`（T23 备忘录）
  /// - 5：新增 `shopping_items`（工具箱 · 采购清单）
  /// - 6：新增 `birthdays`（工具箱 · 朋友生日）
  /// - 7：新增 `calorie_entries`（工具箱 · 每日热量）
  /// - 8：新增 `location_reminders`（工具箱 · 途径提醒）
  ///
  /// 迁移策略：**增量迁移，永不删表**（P0-1）。
  ///
  /// 旧实现是 `deleteTable × 5 → createAll()`，等于「一次 schema 升级 = 用户数据全灭」。
  /// 现在每个版本差一步，只做 `CREATE TABLE IF NOT EXISTS` / `ALTER TABLE ADD COLUMN` /
  /// 数据搬运，任何一步都不会破坏既有行。
  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      await _migrateIncrementally(m, from, to);
      await _createIndexes();
    },
    beforeOpen: (details) async {
      // scheduled_alarms.task_id 的 ON DELETE CASCADE 依赖外键约束，
      // SQLite 默认关闭，必须每次打开连接时显式开启。
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// 逐版本增量迁移（`from` → `to` 可能是跨多版，因此每步都用 `if` 而不是 `switch`）。
  ///
  /// 铁律：
  /// - 只用 `createTable` / `addColumn` / `INSERT ... SELECT` 搬运数据；
  /// - **不调用 `deleteTable` / `DROP TABLE`**（旧表宁可留着当冷备，也不删）；
  /// - 迁移不写业务默认值到已有列上（避免覆盖用户真实数据）。
  Future<void> _migrateIncrementally(Migrator m, int from, int to) async {
    if (from < 2 && to >= 2) {
      await _migrateV1ToV2(m);
    }
    if (from < 3 && to >= 3) {
      // v3 只加表，不改既有列
      await m.createTable(scheduledAlarms);
    }
    if (from < 4 && to >= 4) {
      // v4 只加表（日记 / 备忘录），既有 4 张表一列都没动
      await m.createTable(diaries);
      await m.createTable(memos);
    }
    if (from < 5 && to >= 5) {
      // v5 只加表（采购清单），不动既有表的任何列
      await m.createTable(shoppingItems);
    }
    if (from < 6 && to >= 6) {
      // v6 只加表（朋友生日）
      await m.createTable(birthdays);
    }
    if (from < 7 && to >= 7) {
      // v7 只加表（热量记录）
      await m.createTable(calorieEntries);
    }
    if (from < 8 && to >= 8) {
      // v8 只加表（途径提醒）
      await m.createTable(locationReminders);
    }
  }

  /// v1（单表 `tasks`）→ v2（模板 + 实例）。
  ///
  /// 建两张新表后，把旧表的行搬进新结构；**旧表原样保留**（不 DROP），
  /// 以便迁移出问题时还能人工找回。列名用「存在才取」的宽松策略：
  /// v1 的建表语句已不在代码库里，不应假定它一定长什么样。
  Future<void> _migrateV1ToV2(Migrator m) async {
    await m.createTable(taskTemplates);
    await m.createTable(taskInstances);

    if (!await _tableExists('tasks')) return;
    final rows = await customSelect('SELECT * FROM tasks').get();

    for (final row in rows) {
      final data = row.data;
      final title = _pickString(data, const ['title', 'name'], '未命名任务');
      final type = _pickString(data, const ['type', 'category'], 'study');
      final createdAt =
          _pickDateTime(data, const ['created_at', 'createdAt', 'start_date']) ??
          DateTime.now();
      final legacyId = _pickInt(data, const ['id']);

      final insertedId = await into(taskTemplates).insert(
        TaskTemplatesCompanion.insert(
          // 保留原 id：模板与实例、未来的闹钟记录是靠 id 关联的，改号会断链
          id: Value.absentIfNull(legacyId),
          type: type,
          title: title,
          // v1 没有重复规则：按「单次」迁移，避免凭空长出一串每日实例
          repeatMode: 'once',
          startDate: dateOnly(createdAt),
          createdAt: Value(createdAt),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(taskInstances).insert(
        TaskInstancesCompanion.insert(
          templateId: insertedId,
          occurrenceDate: dateOnly(createdAt),
          titleSnapshot: title,
          typeSnapshot: type,
          status: _pickBool(data, const ['is_done', 'completed'])
              ? 'done'
              : 'todo',
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  }

  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

  static String _pickString(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return fallback;
  }

  static int? _pickInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
    }
    return null;
  }

  static bool _pickBool(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
      if (value is int) return value != 0;
    }
    return false;
  }

  /// drift 默认把 DateTime 存成 unix 秒（INTEGER）；若某版配过
  /// `storeDateTimeAsText`，这里也兼容 ISO 字符串。
  static DateTime? _pickDateTime(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          value * 1000,
          isUtc: true,
        ).toLocal();
      }
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// 取「日期」：统一用本地日期做比较（与 engine/backfill.dart 的语义一致）。
  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// 索引用原生 SQL 建（T22 要求 `(diary_date)` / `(deleted_at)`；T23 要求 `(deleted_at)` / `(pinned)`）。
  ///
  /// 为什么不用 `@TableIndex` 注解：注解依赖代码生成，改一次要重跑 build_runner；
  /// 这里两条 `CREATE INDEX IF NOT EXISTS` 幂等、可以在 `.schema` 里直接核验，
  /// 而且新建库（onCreate）与升级库（onUpgrade）走同一段代码，不会两边不一致。
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_diaries_date ON diaries(diary_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_diaries_deleted ON diaries(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_memos_deleted ON memos(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_memos_pinned ON memos(pinned)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shopping_deleted '
      'ON shopping_items(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shopping_checked '
      'ON shopping_items(checked)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_birthdays_deleted '
      'ON birthdays(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_calorie_date '
      'ON calorie_entries(entry_date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_calorie_deleted '
      'ON calorie_entries(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_location_enabled '
      'ON location_reminders(enabled)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_location_deleted '
      'ON location_reminders(deleted_at)',
    );
  }

  /// 数据库文件的默认位置（应用专属目录，卸载即清）。
  static Future<File> defaultFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'efficiency_app.sqlite'));
  }

  /// 打开数据库：存放于应用专属目录，后台 isolate 执行避免阻塞 UI。
  ///
  /// [file] 只给测试用（真实路径由 [defaultFile] 决定）。
  /// 注意 `NativeDatabase.createInBackground` 是**惰性**的：文件坏了这里不会抛，
  /// 要等第一次查询才炸 —— 所以启动流程必须先跑一次 [assertReadable]。
  static Future<AppDatabase> open({File? file}) async {
    final target = file ?? await defaultFile();
    return AppDatabase(NativeDatabase.createInBackground(target));
  }

  /// 启动自检：真正读一次库头（`sqlite_master`）。
  ///
  /// 文件被截断 / 头部被覆盖 / 根本不是 SQLite 时，这里会抛 `SqliteException`，
  /// 让调用方在 `runApp` 之前就知道「库打不开」，而不是把用户丢在白屏上。
  static Future<void> assertReadable(AppDatabase db) async {
    await db.customSelect('SELECT count(*) AS c FROM sqlite_master').getSingle();
  }

  /// 把损坏的数据库文件**挪到旁边**（改名，不删除），返回新路径。
  ///
  /// 三条铁律：
  /// - 原文件一个字节都不丢：只是改名 + 保留 `-wal` / `-shm` 同名兄弟文件；
  /// - 目录不可写等异常向上抛，由 UI 明确告诉用户「没恢复成功」；
  /// - 文件本来就不存在 → 返回 null（没什么可备份的，直接重建即可）。
  static Future<File?> quarantine(File dbFile) async {
    if (!await dbFile.exists()) return null;
    final target = File('${dbFile.path}.corrupt-${_stamp(DateTime.now())}');
    await dbFile.rename(target.path);
    for (final suffix in const ['-wal', '-shm']) {
      final side = File('${dbFile.path}$suffix');
      if (await side.exists()) {
        await side.rename('${target.path}$suffix');
      }
    }
    return target;
  }

  /// 默认位置的损坏库备份（给启动失败页用）。
  static Future<File?> quarantineDefault() async =>
      quarantine(await defaultFile());

  /// `20261029_031500` —— 文件名里不用冒号（跨平台安全）。
  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}

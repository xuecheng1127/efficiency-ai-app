import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// P0-1 回归测试：**升级不许清库**。
///
/// 旧实现 `onUpgrade` 是 `deleteTable × 5 → createAll()`：schema 一升级
/// 用户数据就全灭。这里让真实文件走一遍「旧版本 → 打开 AppDatabase」的路径，
/// 断言数据还在 —— 不是测某个私有函数，而是测用户实际会经历的那条路。
void main() {
  group('数据库增量迁移（P0-1：升级不清库）', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('eff_migration_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    File dbFile(String name) => File(p.join(tempDir.path, '$name.sqlite'));

    /// 把库「退回」到某个旧版本：drop 掉后来才有的表 + 改 user_version。
    /// 这是生成「真实的旧版文件」最可靠的方式 —— 表结构由 drift 自己建，
    /// 不用手抄 DDL，也就不会因为抄错列名而测出假结果。
    Future<void> downgrade(
      AppDatabase db,
      int version,
      List<String> tablesToDrop,
    ) async {
      for (final table in tablesToDrop) {
        await db.customStatement('DROP TABLE IF EXISTS $table');
      }
      await db.customStatement('PRAGMA user_version = $version');
    }

    test('v3 → v5：模板 / 实例 / 闹钟一行不少，新表建好且能写', () async {
      final file = dbFile('v3');

      // 1) 先按当前版本建库，灌入「老用户」的三类数据
      final seeding = AppDatabase(NativeDatabase(file));
      await seeding.into(seeding.taskTemplates).insert(
        TaskTemplatesCompanion.insert(
          id: const Value(7),
          type: 'study',
          title: '升级前的每日任务',
          repeatMode: 'daily',
          startDate: DateTime(2026, 10, 1),
        ),
      );
      await seeding.into(seeding.taskInstances).insert(
        TaskInstancesCompanion.insert(
          templateId: 7,
          occurrenceDate: DateTime(2026, 10, 1),
          titleSnapshot: '升级前的每日任务',
          typeSnapshot: 'study',
          status: 'done',
          accumulatedSeconds: const Value(125),
        ),
      );
      await seeding.into(seeding.scheduledAlarms).insert(
        ScheduledAlarmsCompanion.insert(
          taskId: 7,
          hour: 7,
          minute: 30,
          repeatRule: 'daily',
        ),
      );
      // 退回 v3：还没有 diaries / memos / shopping_items
      await downgrade(seeding, 3, [
        'diaries',
        'memos',
        'shopping_items',
        'birthdays',
        'calorie_entries',
        'location_reminders',
      ]);
      await seeding.close();

      // 2) 用当前代码打开 → 触发 onUpgrade(3 → 5)
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final templates = await db.select(db.taskTemplates).get();
      final instances = await db.select(db.taskInstances).get();
      final alarms = await db.select(db.scheduledAlarms).get();

      expect(templates, hasLength(1), reason: '升级后模板不应丢失');
      expect(templates.single.title, '升级前的每日任务');
      expect(templates.single.repeatMode, 'daily');
      expect(instances, hasLength(1), reason: '升级后实例不应丢失');
      expect(instances.single.accumulatedSeconds, 125);
      expect(instances.single.status, 'done');
      expect(alarms, hasLength(1), reason: '升级后闹钟不应丢失');
      expect(alarms.single.hour, 7);
      expect(alarms.single.minute, 30);

      // 3) 新表确实建出来了，而且真的能写
      expect(await _tableExists(db, 'diaries'), isTrue);
      expect(await _tableExists(db, 'memos'), isTrue);
      await db.into(db.memos).insert(
        MemosCompanion.insert(
          content: '迁移后新建',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      expect(await db.select(db.memos).get(), hasLength(1));

      // 4) 索引与版本号也到位
      expect(await _indexExists(db, 'idx_diaries_date'), isTrue);
      expect(await _indexExists(db, 'idx_memos_pinned'), isTrue);
      expect(await _indexExists(db, 'idx_shopping_checked'), isTrue);
      final version = (await db
              .customSelect('PRAGMA user_version')
              .getSingle())
          .read<int>('user_version');
      expect(version, db.schemaVersion, reason: '迁移后必须是最新版本');
    });

    test('v4 → v5：只加 shopping_items，既有数据一行不少', () async {
      final file = dbFile('v4');

      final seeding = AppDatabase(NativeDatabase(file));
      final memoId = await seeding.into(seeding.memos).insert(
        MemosCompanion.insert(
          content: 'v4 时代的备忘',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      // 退回 v4：还没有 shopping_items
      await downgrade(seeding, 4, [
        'shopping_items',
        'birthdays',
        'calorie_entries',
        'location_reminders',
      ]);
      await seeding.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final memos = await db.select(db.memos).get();
      expect(memos, hasLength(1), reason: 'v5 只加表，不能动 v4 的数据');
      expect(memos.single.id, memoId);
      expect(memos.single.content, 'v4 时代的备忘');

      expect(await _tableExists(db, 'shopping_items'), isTrue);
      await db.into(db.shoppingItems).insert(
        ShoppingItemsCompanion.insert(
          name: '迁移后新建',
          createdAt: DateTime.now(),
        ),
      );
      expect(await db.select(db.shoppingItems).get(), hasLength(1));
    });

    test('v5 → v6：只加 birthdays，既有数据一行不少', () async {
      final file = dbFile('v5');

      final seeding = AppDatabase(NativeDatabase(file));
      await seeding.into(seeding.shoppingItems).insert(
        ShoppingItemsCompanion.insert(
          name: 'v5 时代的采购项',
          createdAt: DateTime.now(),
        ),
      );
      await downgrade(seeding, 5, [
        'birthdays',
        'calorie_entries',
        'location_reminders',
      ]);
      await seeding.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      expect(await db.select(db.shoppingItems).get(), hasLength(1));
      expect(await _tableExists(db, 'birthdays'), isTrue);
      await db.into(db.birthdays).insert(
        BirthdaysCompanion.insert(
          name: '迁移后新建',
          birthdayMonth: 1,
          birthdayDay: 1,
          createdAt: DateTime.now(),
        ),
      );
      expect(await db.select(db.birthdays).get(), hasLength(1));
    });

    test('v6 → v7：只加 calorie_entries，生日数据一行不少', () async {
      final file = dbFile('v6');

      final seeding = AppDatabase(NativeDatabase(file));
      await seeding.into(seeding.birthdays).insert(
        BirthdaysCompanion.insert(
          name: 'v6 时代的生日',
          birthdayMonth: 6,
          birthdayDay: 12,
          createdAt: DateTime.now(),
        ),
      );
      await downgrade(seeding, 6, ['calorie_entries', 'location_reminders']);
      await seeding.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      expect(await db.select(db.birthdays).get(), hasLength(1));
      expect(await _tableExists(db, 'calorie_entries'), isTrue);
      await db.into(db.calorieEntries).insert(
        CalorieEntriesCompanion.insert(
          entryDate: DateTime(2026, 10, 18),
          meal: 'lunch',
          name: '迁移后新建',
          kcal: 300,
          createdAt: DateTime.now(),
        ),
      );
      expect(await db.select(db.calorieEntries).get(), hasLength(1));
    });

    test('v7 → v8：只加 location_reminders，热量数据一行不少', () async {
      final file = dbFile('v7');

      final seeding = AppDatabase(NativeDatabase(file));
      await seeding.into(seeding.calorieEntries).insert(
        CalorieEntriesCompanion.insert(
          entryDate: DateTime(2026, 10, 18),
          meal: 'lunch',
          name: 'v7 时代的午餐',
          kcal: 520,
          createdAt: DateTime.now(),
        ),
      );
      await downgrade(seeding, 7, ['location_reminders']);
      await seeding.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      expect(await db.select(db.calorieEntries).get(), hasLength(1));
      expect(await _tableExists(db, 'location_reminders'), isTrue);
      await db.into(db.locationReminders).insert(
        LocationRemindersCompanion.insert(
          title: '迁移后新建',
          placeName: '超市',
          latitude: 39.9,
          longitude: 116.4,
          createdAt: DateTime.now(),
        ),
      );
      expect(await db.select(db.locationReminders).get(), hasLength(1));
    });

    test('v2 → v4：跨两版链式迁移，数据存活、中间表补齐', () async {
      final file = dbFile('v2');

      final seeding = AppDatabase(NativeDatabase(file));
      await seeding.into(seeding.taskTemplates).insert(
        TaskTemplatesCompanion.insert(
          id: const Value(1),
          type: 'fitness',
          title: 'v2 时代的任务',
          repeatMode: 'weekly',
          startDate: DateTime(2026, 9, 1),
        ),
      );
      await seeding.into(seeding.taskInstances).insert(
        TaskInstancesCompanion.insert(
          templateId: 1,
          occurrenceDate: DateTime(2026, 9, 1),
          titleSnapshot: 'v2 时代的任务',
          typeSnapshot: 'fitness',
          status: 'todo',
        ),
      );
      await downgrade(seeding, 2, [
        'scheduled_alarms',
        'diaries',
        'memos',
        'shopping_items',
        'birthdays',
        'calorie_entries',
        'location_reminders',
      ]);
      await seeding.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      expect(await db.select(db.taskTemplates).get(), hasLength(1));
      expect(await db.select(db.taskInstances).get(), hasLength(1));
      // 链式迁移把 v3 / v4 / v5 的表都建上
      expect(await _tableExists(db, 'scheduled_alarms'), isTrue);
      expect(await _tableExists(db, 'diaries'), isTrue);
      expect(await _tableExists(db, 'memos'), isTrue);
      expect(await _tableExists(db, 'shopping_items'), isTrue);
      expect(await _tableExists(db, 'birthdays'), isTrue);
    });

    test('v1 → v2：单表 tasks 的数据搬进新结构，旧表原样保留', () async {
      final file = dbFile('v1');

      // v1 的库只有一张 `tasks` 表：把当前所有表全删掉，只留这张
      final seeding = AppDatabase(NativeDatabase(file));
      for (final table in [
        'scheduled_alarms',
        'task_instances',
        'task_templates',
        'diaries',
        'memos',
        'shopping_items',
        'birthdays',
        'calorie_entries',
        'location_reminders',
      ]) {
        await seeding.customStatement('DROP TABLE IF EXISTS $table');
      }
      await seeding.customStatement('''
        CREATE TABLE tasks (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          type TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          is_done INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await seeding.customStatement(
        'INSERT INTO tasks (id, title, type, created_at, is_done) '
        "VALUES (3, 'v1 的老任务', 'study', 1700000000, 1)",
      );
      await seeding.customStatement('PRAGMA user_version = 1');
      await seeding.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final templates = await db.select(db.taskTemplates).get();
      expect(templates, hasLength(1));
      expect(templates.single.id, 3, reason: '保留原 id，历史引用不断链');
      expect(templates.single.title, 'v1 的老任务');

      final instances = await db.select(db.taskInstances).get();
      expect(instances, hasLength(1));
      expect(
        instances.single.status,
        'done',
        reason: '旧 is_done=1 应映射为 done',
      );

      // 旧表不 DROP：万一迁移有偏差，原始数据还在，可人工找回
      expect(await _tableExists(db, 'tasks'), isTrue);
    });
  });
}

Future<bool> _tableExists(AppDatabase db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(name)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<bool> _indexExists(AppDatabase db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
        variables: [Variable<String>(name)],
      )
      .get();
  return rows.isNotEmpty;
}

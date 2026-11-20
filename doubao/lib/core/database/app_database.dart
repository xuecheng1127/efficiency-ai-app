import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/birthdays.dart';
import 'tables/calorie_entries.dart';
import 'tables/diaries.dart';
import 'tables/location_reminders.dart';
import 'tables/memos.dart';
import 'tables/scheduled_alarms.dart';
import 'tables/shopping_items.dart';
import 'tables/task_instances.dart';
import 'tables/task_templates.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [TaskTemplates, TaskInstances, ScheduledAlarms, Diaries, Memos, ShoppingItems, Birthdays, LocationReminders, CalorieEntries])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 9;

  /// 供测试注入的内存/临时 executor
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openAppDatabase());

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  /// 恢复数据库后调用：丢弃旧单例，下次访问重新打开新文件
  static void resetInstance() {
    _instance = null;
  }

  static QueryExecutor _openAppDatabase() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'efficiency_app.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  /// 性能索引（R1）：覆盖高频查询列，IF NOT EXISTS 可重复执行
  static const List<String> _indexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_task_instances_date_status '
        'ON task_instances(occurrence_date, status)',
    'CREATE INDEX IF NOT EXISTS idx_task_instances_template '
        'ON task_instances(template_id)',
    'CREATE INDEX IF NOT EXISTS idx_diaries_date ON diaries(diary_date)',
    'CREATE INDEX IF NOT EXISTS idx_memos_deleted_pinned '
        'ON memos(deleted_at, pinned)',
    'CREATE INDEX IF NOT EXISTS idx_shopping_checked ON shopping_items(checked)',
    'CREATE INDEX IF NOT EXISTS idx_calorie_entry_date '
        'ON calorie_entries(entry_date)',
    'CREATE INDEX IF NOT EXISTS idx_location_enabled '
        'ON location_reminders(enabled)',
    'CREATE INDEX IF NOT EXISTS idx_birthdays_month_day '
        'ON birthdays(birthday_month, birthday_day)',
  ];

  Future<void> _createIndexes(Migrator m) async {
    for (final sql in _indexStatements) {
      await m.database.customStatement(sql);
    }
  }

  /// 迁移：v1→v2 建 scheduled_alarms 表
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes(m);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(scheduledAlarms);
          }
          if (from < 3) {
            await m.createTable(diaries);
          }
          if (from < 4) {
            await m.createTable(memos);
          }
          if (from < 5) {
            await m.createTable(shoppingItems);
          }
          if (from < 6) {
            await m.createTable(birthdays);
          }
          if (from < 7) {
            await m.createTable(locationReminders);
          }
          if (from < 8) {
            await m.createTable(calorieEntries);
          }
          if (from < 9) {
            await _createIndexes(m);
          }
        },
      );
}

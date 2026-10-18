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
  int get schemaVersion => 8;

  /// 供测试注入的内存/临时 executor
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openAppDatabase());

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  static QueryExecutor _openAppDatabase() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'efficiency_app.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  /// 迁移：v1→v2 建 scheduled_alarms 表
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
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
        },
      );
}

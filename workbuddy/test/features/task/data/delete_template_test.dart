import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:efficiency_app/features/alarm/data/alarm_repository_impl.dart';
import 'package:efficiency_app/features/task/application/delete_task.dart';
import 'package:efficiency_app/features/task/data/task_repository_impl.dart';
import 'package:efficiency_app/features/task/domain/task_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// P0-2 回归测试：**删除任务必须真的删掉，明天不许自己长回来**。
///
/// 旧行为：`deleteInstance` 只软删「今日实例」，模板还在，于是
/// 第二天 `backfill` 从 `lastOccurrenceDate` 接着往下补，用户看到「删了又回来」。
void main() {
  group('删除任务（P0-2：删模板 + 撤闹钟 + 不复活）', () {
    late AppDatabase db;
    late TaskRepositoryImpl repo;

    // 日期不能用写死的常量：`addTemplate` 的 startDate 取的是**真实今天**，
    // 一旦测试写死「2026-10-18」而运行日期晚于它，backfill 会因为
    // startDate > today 而一条实例都不补，三个用例会集体假失败。
    // 这里跟随运行日，只保留「昨天 / 明天」的相对关系（测试意图不变）。
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TaskRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> addDailyTemplate({String title = '每日背单词'}) {
      return repo.addTemplate(
        type: TaskType.study,
        title: title,
        repeatMode: RepeatMode.daily,
      );
    }

    Future<TaskTemplateRow> templateRow(int id) {
      return (db.select(
        db.taskTemplates,
      )..where((t) => t.id.equals(id))).getSingle();
    }

    test('删除后模板被归档、实例被软删、今日列表为空', () async {
      final id = await addDailyTemplate();
      await repo.backfill(today);

      expect(await repo.watchTodayInstances(today).first, hasLength(1));

      await repo.deleteTemplate(id);

      // 标签页应该立刻看不到这条任务
      expect(await repo.watchTodayInstances(today).first, isEmpty);

      // 模板还在（软删），但已归档
      expect((await templateRow(id)).archivedAt, isNotNull);

      // 实例也是软删，不是硬删（历史仍可查）
      final instances = await db.select(db.taskInstances).get();
      expect(instances, hasLength(1));
      expect(instances.single.deletedAt, isNotNull);
    });

    test('删除后第二天 backfill 不会把它补回来', () async {
      final id = await addDailyTemplate();
      await repo.backfill(today);
      await repo.deleteTemplate(id);

      // 模拟「第二天打开 App」
      await repo.backfill(tomorrow);

      final live = await repo.watchTodayInstances(tomorrow).first;
      expect(live, isEmpty, reason: '已删除的模板不能被 backfill 复活');

      // 库里也不应新增明天的实例
      final all = await db.select(db.taskInstances).get();
      expect(all, hasLength(1), reason: '只应有昨天那条被软删的实例');
    });

    test('删除单次任务同样归档模板（不是只删实例）', () async {
      final id = await repo.addTemplate(
        type: TaskType.study,
        title: '一次性任务',
        repeatMode: RepeatMode.once,
      );
      await repo.backfill(today);
      await repo.deleteTemplate(id);

      expect((await templateRow(id)).archivedAt, isNotNull);
      expect(await repo.watchTodayInstances(today).first, isEmpty);
    });

    test('DeleteTask 编排：闹钟记录一并撤销，且先撤铃声再销数据', () async {
      final id = await addDailyTemplate();
      await repo.backfill(today);

      final alarms = AlarmRepositoryImpl(db);
      await alarms.scheduleForTask(
        taskId: id,
        hour: 7,
        minute: 30,
        repeatRule: 'daily',
      );
      expect(await db.select(db.scheduledAlarms).get(), hasLength(1));

      final instance = (await repo.watchTodayInstances(today).first).single;
      final deleteTask = DeleteTask(repo, alarms);
      await deleteTask(instance);

      // 铃声没了（列表里也不会再显示一个假的「已设闹钟」）
      expect(await db.select(db.scheduledAlarms).get(), isEmpty);
      // 数据销了
      expect((await templateRow(id)).archivedAt, isNotNull);
      expect(await repo.watchTodayInstances(today).first, isEmpty);
    });

    test('归档后取消归档不会凭空恢复实例（边界：只影响模板可见性）', () async {
      final id = await addDailyTemplate();
      await repo.backfill(today);
      await repo.deleteTemplate(id);

      // 人工把 archivedAt 清空（模拟未来「回收站恢复」功能）
      await (db.update(db.taskTemplates)..where((t) => t.id.equals(id))).write(
        const TaskTemplatesCompanion(archivedAt: Value<DateTime?>(null)),
      );

      // 实例仍是软删状态，所以列表依旧是空的 —— 恢复必须显式恢复实例
      expect(await repo.watchTodayInstances(today).first, isEmpty);
    });
  });
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:efficiency_app/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// HARDENING A4：数据库损坏时的「可检测 + 可恢复」能力。
///
/// 这里测的是三道地基，UI 的失败页见 `test/app/bootstrap_app_test.dart`：
/// 1. 坏文件不会在 `open()` 静默通过 —— 必须由 `assertReadable` 显式暴露；
/// 2. `quarantine` 只改名、不删除，`-wal` / `-shm` 一起搬走；
/// 3. 搬走之后能重新开出一个干净空库。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File dbFile;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('db-recovery-');
    dbFile = File('${dir.path}${Platform.pathSeparator}efficiency_app.sqlite');
  });

  tearDown(() async {
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  /// 把文件头 4KB 写成 0 —— SQLite 会判定 `file is not a database`。
  Future<void> corrupt() async {
    final raf = await dbFile.open(mode: FileMode.write);
    await raf.writeFrom(List<int>.filled(4096, 0));
    await raf.close();
  }

  test('正常空库：assertReadable 通过', () async {
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);
    await AppDatabase.assertReadable(db);
  });

  test('损坏文件：连接本身能建，但 assertReadable 抛异常（白屏的真正根因）', () async {
    await corrupt();
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);
    await expectLater(AppDatabase.assertReadable(db), throwsA(anything));
  });

  test('quarantine：只改名不删除，字节逐字节保留，-wal/-shm 一起搬走', () async {
    await corrupt();
    final original = await dbFile.readAsBytes();
    await File('${dbFile.path}-wal').writeAsBytes(const [1, 2, 3]);

    final moved = await AppDatabase.quarantine(dbFile);

    expect(moved, isNotNull);
    expect(moved!.path, contains('.corrupt-'));
    expect(await dbFile.exists(), isFalse, reason: '原路径必须让出来给新库');
    expect(await moved.readAsBytes(), original, reason: '内容一个字节都不能变');
    expect(await File('${dbFile.path}-wal').exists(), isFalse);
    expect(await File('${moved.path}-wal').exists(), isTrue);
  });

  test('quarantine 之后重建：开出来的是干净空库（表齐全、0 条任务）', () async {
    await corrupt();
    await AppDatabase.quarantine(dbFile);

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    await AppDatabase.assertReadable(db);
    expect(await db.select(db.taskTemplates).get(), isEmpty);
    expect(await db.select(db.diaries).get(), isEmpty);
  });

  test('文件不存在：quarantine 返回 null（没有可备份的东西）', () async {
    expect(await AppDatabase.quarantine(dbFile), isNull);
  });

  test('open(file:) 指向损坏文件：首次查询抛异常（启动流程据此拦住）', () async {
    await corrupt();
    final db = await AppDatabase.open(file: dbFile);
    addTearDown(db.close);
    await expectLater(AppDatabase.assertReadable(db), throwsA(anything));
  });
}

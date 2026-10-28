import 'package:flutter_test/flutter_test.dart';
import 'package:efficiency_app/core/database/app_database.dart';

void main() {
  group('启动兜底', () {
    test('resetInstance 可重复调用不抛异常', () {
      AppDatabase.resetInstance();
      AppDatabase.resetInstance();
    });

    test('schemaVersion 为 8', () {
      expect(AppDatabase.instance.schemaVersion, 8);
    });
  });
}

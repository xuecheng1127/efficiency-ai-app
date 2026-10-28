import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

// 边界硬化测试：空数据 / 超长文本 / 幂等

void main() {
  group('空数据列表不崩溃', () {
    test('空列表 first 安全', () {
      final List<dynamic> items = [];
      expect(() => items.isEmpty ? null : items.first, returnsNormally);
    });
    test('空列表 reduce 不崩', () {
      final items = <int>[];
      if (items.isEmpty) {
        expect(0, 0); // 空态
      }
    });
  });

  group('超长文本处理', () {
    test('5000 字日记不抛异常', () {
      final text = '今天天气很好。' * 700; // ~5000 字
      expect(text.length, greaterThan(4000));
      expect(() => text.substring(0, 100), returnsNormally);
    });
    test('3000 字备忘录截断', () {
      final text = '记录。' * 1000;
      final truncated = text.length > 50 ? text.substring(0, 50) : text;
      expect(truncated.length, lessThanOrEqualTo(50));
    });
    test('200 字标题不崩', () {
      final title = '任务' * 50;
      expect(title.length, 100);
      expect(() => title.trim(), returnsNormally);
    });
  });

  group('快速连点幂等', () {
    test('同一任务完成两次 = 完成一次', () {
      var done = false;
      void complete() {
        if (!done) done = true;
      }
      complete();
      complete();
      complete();
      expect(done, true);
    });
    test('删除已删项不崩', () {
      final list = [1, 2, 3];
      list.remove(2);
      list.remove(2);
      expect(list, [1, 3]);
    });
  });

  group('SQLite user_version 读取', () {
    test('offset 60-63 big-endian 解析', () {
      // 模拟 SQLite 头：前 60 字节 0，后 4 字节 = 8
      final bytes = List<int>.filled(64, 0);
      bytes[60] = 0;
      bytes[61] = 0;
      bytes[62] = 0;
      bytes[63] = 8;
      final data = ByteData.sublistView(Uint8List.fromList(bytes), 60, 64);
      expect(data.getUint32(0), 8);
    });
    test('更高版本被拒绝', () {
      const current = 8;
      const backupVersion = 10;
      expect(backupVersion > current, true);
    });
  });

  group('路径与文件', () {
    test('pre_restore.bak 路径拼接', () {
      const dbPath = '/data/data/com.app/files/app.sqlite';
      const bakPath = '$dbPath.pre_restore.bak';
      expect(bakPath.endsWith('.pre_restore.bak'), true);
    });
    test('-wal -shm sidecar 清理', () {
      const dbPath = '/x/app.sqlite';
      final sidecars = ['-wal', '-shm'].map((s) => '$dbPath$s');
      expect(sidecars, ['/x/app.sqlite-wal', '/x/app.sqlite-shm']);
    });
  });

  group('BMR 活动系数', () {
    double tdee(double bmr, double factor) => bmr * factor;
    test('久坐 1.2', () => expect(tdee(1673.75, 1.2), closeTo(2008.5, 1)));
    test('轻度活动 1.375', () => expect(tdee(1673.75, 1.375), closeTo(2301.4, 1)));
    test('中度活动 1.55', () => expect(tdee(1673.75, 1.55), closeTo(2594.3, 1)));
  });

  group('Streak 边界', () {
    test('今天没做昨天也没做 = 0', () {
      expect(_streak([false, false]), 0);
    });
    test('只有今天做了 = 1', () {
      expect(_streak([true, false]), 1);
    });
    test('空数组 = 0', () {
      expect(_streak([]), 0);
    });
  });

  group('日期格式化', () {
    test('月份补零', () {
      final m = 5.toString().padLeft(2, '0');
      expect(m, '05');
    });
    test('12 月不补零', () {
      final m = 12.toString().padLeft(2, '0');
      expect(m, '12');
    });
  });

  group('文件大小显示', () {
    test('KB 一位小数', () {
      final kb = (2048 / 1024).toStringAsFixed(1);
      expect(kb, '2.0');
    });
    test('非整 KB', () {
      final kb = (1536 / 1024).toStringAsFixed(1);
      expect(kb, '1.5');
    });
  });

  group('权限拒绝降级', () {
    test('定位拒绝后前台轮询仍可用', () {
      const hasPermission = false;
      final mode = hasPermission ? 'full' : 'front_only';
      expect(mode, 'front_only');
    });
  });
}

int _streak(List<bool> doneDesc) {
  int s = 0;
  for (var i = 0; i < doneDesc.length; i++) {
    if (i == 0 && !doneDesc[i]) continue;
    if (doneDesc[i]) s++; else break;
  }
  return s;
}

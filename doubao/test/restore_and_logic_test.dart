import 'package:flutter_test/flutter_test.dart';

// BMR Mifflin-St Jeor 公式测试
double bmrMale(double kg, double cm, int age) =>
    10 * kg + 6.25 * cm - 5 * age + 5;
double bmrFemale(double kg, double cm, int age) =>
    10 * kg + 6.25 * cm - 5 * age - 161;

void main() {
  group('BMR Mifflin-St Jeor', () {
    test('男 70kg 175cm 25岁 = 1673.75', () {
      expect(bmrMale(70, 175, 25), closeTo(1673.75, 0.01));
    });
    test('女 70kg 175cm 25岁 = 1507.75', () {
      expect(bmrFemale(70, 175, 25), closeTo(1507.75, 0.01));
    });
  });

  group('Workbench mode 映射', () {
    test('"tasks" -> tasks', () {
      expect(_parseMode('tasks'), 'tasks');
    });
    test('"diary" -> diary', () {
      expect(_parseMode('diary'), 'diary');
    });
    test('"both" -> both', () {
      expect(_parseMode('both'), 'both');
    });
    test('非法值 -> null', () {
      expect(_parseMode('xxx'), isNull);
    });
    test('空串 -> null', () {
      expect(_parseMode(''), isNull);
    });
  });

  group('采购清单排序', () {
    test('已购项排到未购项之后', () {
      final items = [
        _Item('牛奶', true),
        _Item('面包', false),
        _Item('鸡蛋', true),
        _Item('苹果', false),
      ];
      items.sort((a, b) {
        final c = a.checked ? 1 : -1;
        return c.compareTo(b.checked ? 1 : -1);
      });
      expect(items[0].checked, false);
      expect(items[1].checked, false);
      expect(items[2].checked, true);
      expect(items[3].checked, true);
    });
  });

  group('Streak 计算', () {
    test('连续 3 天 = 3', () {
      expect(_calcStreak([true, true, true]), 3);
    });
    test('断 1 天归零', () {
      // [今天=true, 昨天=true, 前天=false, 大前天=true] -> streak=2
      // 因为前天没做，中断了
      expect(_calcStreak([true, true, false, true]), 2);
    });
    test('今天没做但昨天做了不扣', () {
      // [昨天=true, 今天=false] -> 仍为 1
      expect(_calcStreak([false, true]), 1);
    });
  });
}

String? _parseMode(String v) {
  switch (v) {
    case 'tasks':
    case 'diary':
    case 'both':
      return v;
    default:
      return null;
  }
}

int _calcStreak(List<bool> doneDesc) {
  // doneDesc: [今天, 昨天, 前天, ...]
  int streak = 0;
  for (var i = 0; i < doneDesc.length; i++) {
    if (i == 0 && !doneDesc[i]) {
      // 今天没做：不扣，但也不加
      continue;
    }
    if (doneDesc[i]) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

class _Item {
  final String name;
  final bool checked;
  _Item(this.name, this.checked);
}

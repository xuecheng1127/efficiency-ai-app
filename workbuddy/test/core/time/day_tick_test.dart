import 'package:efficiency_app/core/time/day_tick.dart';
import 'package:flutter_test/flutter_test.dart';

/// HARDENING A5：跨零点节拍的边界。
///
/// 这里只测「算出来的时间点对不对」和「流的第一次吐值」——
/// 真实的 `await Future.delayed` 不放进单测（会真的等一整夜）。
void main() {
  group('nextMidnightAfter：跨月 / 跨年 / 闰日都要落在次日 00:00:01', () {
    void expectNext(DateTime from, DateTime expectedDay) {
      final next = nextMidnightAfter(from);
      expect(next, expectedDay.add(const Duration(seconds: 1)));
    }

    test('普通日：10-29 23:58 → 10-30 00:00:01', () {
      expectNext(DateTime(2026, 10, 29, 23, 58), DateTime(2026, 10, 30));
    });

    test('月末：10-31 23:59 → 11-01（不是 10-32）', () {
      expectNext(DateTime(2026, 10, 31, 23, 59), DateTime(2026, 11, 1));
    });

    test('年末：12-31 23:59 → 次年 01-01', () {
      expectNext(DateTime(2026, 12, 31, 23, 59), DateTime(2027, 1, 1));
    });

    test('闰年 2 月末：2028-02-28 → 02-29（有 29 号）', () {
      expectNext(DateTime(2028, 2, 28, 23, 59), DateTime(2028, 2, 29));
      expectNext(DateTime(2028, 2, 29, 23, 59), DateTime(2028, 3, 1));
    });
  });

  test('dayOnly 归一化到当天零点（丢掉时分秒）', () {
    expect(dayOnly(DateTime(2026, 10, 29, 23, 59, 59)), DateTime(2026, 10, 29));
  });

  test('dayTickStream 第一次吐出的是「今天」的零点', () async {
    final fixed = DateTime(2026, 10, 29, 13, 45, 12);
    final first = await dayTickStream(clock: () => fixed).first;
    expect(first, DateTime(2026, 10, 29));
  });
}

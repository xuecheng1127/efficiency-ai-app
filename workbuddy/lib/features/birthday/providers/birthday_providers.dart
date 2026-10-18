import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/birthday_repository_impl.dart';
import '../domain/birthday.dart';
import '../domain/birthday_repository.dart';

final birthdayRepositoryProvider = Provider<BirthdayRepository>((ref) {
  return BirthdayRepositoryImpl(ref.watch(databaseProvider));
});

final birthdayListProvider = StreamProvider<List<Birthday>>((ref) {
  return ref.watch(birthdayRepositoryProvider).watchAll();
});

/// 已按「距离生日天数」升序排好（7 天内的自然排最前）。
///
/// 为什么排序放 Provider：跨零点后 `daysUntil` 会变，重新 build 就能自动刷新，
/// 页面里不用自己算日期。
final upcomingBirthdaysProvider = Provider<List<BirthdayOccurrence>>((ref) {
  final list = ref.watch(birthdayListProvider).value ?? const <Birthday>[];
  return upcomingBirthdays(list, DateTime.now());
});

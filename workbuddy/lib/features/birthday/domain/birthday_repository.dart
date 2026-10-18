import 'birthday.dart';

/// 生日仓库。
abstract interface class BirthdayRepository {
  /// 未删除的全部记录（排序由 `upcomingBirthdays` 纯函数负责）。
  Stream<List<Birthday>> watchAll();

  Future<Birthday?> findById(int id);

  /// 新建，返回 id。名字为空不落库（返回 null）。
  Future<int?> create({
    required String name,
    required int month,
    required int day,
    required BirthdayCalendar calendar,
    int? year,
    String? groupTag,
    int advanceDays = 3,
    String? notes,
  });

  Future<void> update(
    int id, {
    String? name,
    int? month,
    int? day,
    BirthdayCalendar? calendar,
    int? year,
    bool clearYear = false,
    String? groupTag,
    bool clearGroupTag = false,
    int? advanceDays,
    String? notes,
    bool clearNotes = false,
  });

  Future<void> softDelete(int id);

  /// 撤销删除（把 `deletedAt` 清掉）。
  Future<void> restore(int id);

  /// 恢复提醒时需要知道「有哪些人」：给启动时的批量重排用。
  Future<List<Birthday>> all();
}

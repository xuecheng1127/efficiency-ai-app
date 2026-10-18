import 'package:drift/drift.dart';

/// 朋友生日（模块2 插件 · 规格：birthdays）。
///
/// `calendar_type`：`solar`（公历）/ `lunar`（农历）。
/// 农历换算**全部交给 `lunar` 包**，本工程不手写任何历法算法。
class Birthdays extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  /// 出生年（可空：很多人只记得月日）
  IntColumn get birthdayYear => integer().nullable()();

  /// 农历时是农历月（1–12，不含闰月标记）
  IntColumn get birthdayMonth => integer()();

  /// 农历时是农历日（1–30）
  IntColumn get birthdayDay => integer()();

  /// `solar` | `lunar`
  TextColumn get calendarType => text().withDefault(const Constant('solar'))();

  /// 分组标签（可空）：家人 / 朋友 / 同事…
  TextColumn get groupTag => text().nullable()();

  /// 提前几天提醒（0 = 当天）
  IntColumn get advanceDays => integer().withDefault(const Constant(3))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}

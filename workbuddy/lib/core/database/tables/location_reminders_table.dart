import 'package:drift/drift.dart';

/// 途径提醒（模块2 插件 · 规格：location_reminders）。
///
/// 一行 = 一个地理围栏：走到「超市」附近 200m 内提醒我买菜。
class LocationReminders extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 提醒文案（通知标题）
  TextColumn get title => text()();

  /// 地点名（用户看得懂的名字，不反查地理编码）
  TextColumn get placeName => text()();

  RealColumn get latitude => real()();

  RealColumn get longitude => real()();

  /// 触发半径（米），默认 200
  IntColumn get radiusMeters => integer().withDefault(const Constant(200))();

  /// `enter`（进入）/ `exit`（离开）
  TextColumn get triggerOn => text().withDefault(const Constant('enter'))();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// 上次触发时间（24 小时内不重复提醒）
  DateTimeColumn get notifiedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}

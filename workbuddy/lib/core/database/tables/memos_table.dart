import 'package:drift/drift.dart';

/// 备忘表（T23 规格第二节，字段一一对应）。
///
/// 定位：**极低摩擦的随手记** —— 一条备忘就是一坨纯文本 + 是否置顶 + 可选纸色。
/// 刻意**不做**：富文本、标签、双链、附件。
class Memos extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 纯文本，允许换行
  TextColumn get content => text()();

  /// 0/1 置顶（置顶区排最前）
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  /// 可选纸色：`yellow` / `blue` / `green`（null = 默认纸色）
  TextColumn get color => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// 软删除
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

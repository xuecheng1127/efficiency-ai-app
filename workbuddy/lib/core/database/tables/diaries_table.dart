import 'package:drift/drift.dart';

/// 日记表（T22 规格第二节，字段一一对应，**一字不改**）。
///
/// 约定：
/// - `content` 是**纯文本**（V1.0 不做富文本），排版由 `cjk_layout.dart` 引擎负责；
/// - `diaryDate` 存「当天 0 点」，用于按日归档与排序；
/// - `coverPath` 存**相对路径**（如 `diary_media/xxx.jpg`），绝不存绝对路径
///   —— 沙盒路径会变，存绝对路径在换机/重装后全是死链；
/// - `deletedAt` 软删除（列表查询一律过滤）。
class Diaries extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withDefault(const Constant(''))();

  TextColumn get content => text().withDefault(const Constant(''))();

  /// `lined` = 横线本 / `blank` = 空白本
  TextColumn get templateType => text().withDefault(const Constant('lined'))();

  RealColumn get fontSize => real().withDefault(const Constant(16.0))();

  /// null = 系统默认字体
  TextColumn get fontFamily => text().nullable()();

  /// 封面/图片相对路径（不存绝对路径）
  TextColumn get coverPath => text().nullable()();

  /// 归属日期（当天 0 点）
  DateTimeColumn get diaryDate => dateTime()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}

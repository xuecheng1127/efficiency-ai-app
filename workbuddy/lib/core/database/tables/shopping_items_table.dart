import 'package:drift/drift.dart';

/// 采购清单（模块2 插件 · 规格：shopping_items）。
///
/// 定位：**最低摩擦的清单** —— 打字回车就进清单，点一行就勾掉。
/// 刻意不做：数量编辑弹窗、单价统计、清单归档（V1 只保留「从上次清单恢复」）。
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 商品名（用户输入，原样保存；空白输入不落库）
  TextColumn get name => text()();

  /// 数量，默认 1（V1 不在 UI 暴露编辑，字段先留住）
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  /// 分类（可空）；空 → UI 归到「其他」
  TextColumn get category => text().nullable()();

  /// 是否已购
  BoolColumn get checked => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  /// 勾选时间（取消勾选时置空；用于「本次清单」的先后顺序）
  DateTimeColumn get checkedAt => dateTime().nullable()();

  /// 软删除
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

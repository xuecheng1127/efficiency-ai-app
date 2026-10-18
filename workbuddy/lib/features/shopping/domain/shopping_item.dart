/// 采购清单的领域实体与**纯函数**分组逻辑。
///
/// 分组放在 domain（不放进 Widget）：它是「怎么排序」的业务规则，
/// 抽出来才能在 `test/` 里脱离 UI 验证（未购在上 / 已购沉底 / 未分类归「其他」）。
library;

/// 未填分类时的归组名。
const String kOtherCategory = '其他';

/// 一条采购项（映射 `shopping_items` 表；不直接用 Drift 生成类，见 T01 红线）。
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.category,
    required this.checked,
    required this.createdAt,
    this.checkedAt,
    this.deletedAt,
  });

  final int id;
  final String name;
  final int quantity;

  /// null / 空白 → 归「其他」
  final String? category;

  final bool checked;
  final DateTime createdAt;
  final DateTime? checkedAt;
  final DateTime? deletedAt;

  /// 展示用分组名（空白分类统一成「其他」）。
  String get categoryLabel {
    final c = category?.trim() ?? '';
    return c.isEmpty ? kOtherCategory : c;
  }

  ShoppingItem copyWith({
    String? name,
    int? quantity,
    String? category,
    bool? checked,
    DateTime? checkedAt,
    DateTime? deletedAt,
    bool clearCheckedAt = false,
    bool clearCategory = false,
    bool clearDeletedAt = false,
  }) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: clearCategory ? null : (category ?? this.category),
      checked: checked ?? this.checked,
      createdAt: createdAt,
      checkedAt: clearCheckedAt ? null : (checkedAt ?? this.checkedAt),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

/// 一组（同一分类）的展示数据：未购在上、已购沉底。
class ShoppingGroup {
  const ShoppingGroup({
    required this.category,
    required this.pending,
    required this.done,
  });

  final String category;
  final List<ShoppingItem> pending;
  final List<ShoppingItem> done;

  int get total => pending.length + done.length;
  bool get hasPending => pending.isNotEmpty;
}

/// 分组 + 排序（**纯函数**，无 IO、无 Flutter）。
///
/// 规则：
/// 1. 同一分类内：未购在前、已购在后；各自按创建时间倒序（新加的排前面）；
/// 2. 组之间：**还有未购的组排前面**（用户一眼看到要买的），纯已购的组沉底；
/// 3. 「其他」在同类组里排最后 —— 它是兜底桶，不该抢最上面。
List<ShoppingGroup> groupShoppingItems(List<ShoppingItem> items) {
  final alive = items.where((i) => i.deletedAt == null).toList();

  final buckets = <String, List<ShoppingItem>>{};
  for (final item in alive) {
    buckets.putIfAbsent(item.categoryLabel, () => []).add(item);
  }

  int byCreatedDesc(ShoppingItem a, ShoppingItem b) {
    final c = b.createdAt.compareTo(a.createdAt);
    return c != 0 ? c : b.id.compareTo(a.id);
  }

  final groups = <ShoppingGroup>[];
  for (final entry in buckets.entries) {
    final pending = entry.value.where((i) => !i.checked).toList()
      ..sort(byCreatedDesc);
    final done = entry.value.where((i) => i.checked).toList()
      ..sort((a, b) {
        final ca = a.checkedAt ?? a.createdAt;
        final cb = b.checkedAt ?? b.createdAt;
        final c = cb.compareTo(ca);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    groups.add(
      ShoppingGroup(category: entry.key, pending: pending, done: done),
    );
  }

  groups.sort((a, b) {
    if (a.hasPending != b.hasPending) return a.hasPending ? -1 : 1;
    final aOther = a.category == kOtherCategory;
    final bOther = b.category == kOtherCategory;
    if (aOther != bOther) return aOther ? 1 : -1;
    return a.category.compareTo(b.category);
  });
  return groups;
}

/// 汇总：还有多少项没买（空态之外、AppBar 副标题用）。
int pendingCount(List<ShoppingItem> items) {
  return items.where((i) => i.deletedAt == null && !i.checked).length;
}

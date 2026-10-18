import 'memo.dart';

/// 备忘仓库抽象（Domain 定接口，Data 给实现）。
///
/// 只有 6 个动作，对应规格 §3 的全部功能：看 / 记 / 改 / 删 / 置顶 / 搜。
abstract interface class MemoRepository {
  /// 未删除的备忘：**置顶在前**，组内按更新时间倒序。
  Stream<List<Memo>> watchAll();

  Future<Memo?> findById(int id);

  /// 新建，返回 id。内容由调用方保证非空（空内容不落库，见规格 §3.3）。
  Future<int> create({
    required String content,
    bool pinned = false,
    String? color,
  });

  Future<void> update(int id, {String? content, bool? pinned, String? color});

  Future<void> setPinned(int id, bool pinned);

  /// 软删除（写 deletedAt；重启不复活）
  Future<void> softDelete(int id);
}

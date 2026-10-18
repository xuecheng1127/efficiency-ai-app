import 'diary_entry.dart';

/// 日记仓库抽象（依赖倒置：Domain 定接口，Data 给实现）。
abstract interface class DiaryRepository {
  /// 全部未删除日记（按 diaryDate 倒序，同日按更新时间倒序）。
  Stream<List<DiaryEntry>> watchAll();

  /// 关键词搜索（标题 + 正文，大小写不敏感由 SQLite LIKE 负责）。
  Future<List<DiaryEntry>> search(String keyword);

  Future<DiaryEntry?> findById(int id);

  /// 新建，返回新记录 id。
  Future<int> create({
    required String title,
    required String content,
    required String templateType,
    required double fontSize,
    String? fontFamily,
    DateTime? diaryDate,
  });

  /// 局部更新（只写传进来的字段）。
  Future<void> update(
    int id, {
    String? title,
    String? content,
    String? templateType,
    double? fontSize,
    String? fontFamily,
    String? coverPath,
  });

  /// 软删除（写 deletedAt，列表自然消失；重启不复活）。
  Future<void> softDelete(int id);
}

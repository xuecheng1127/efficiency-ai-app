import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 日记图片的本地存储（规格 §2「图片存储」，PRD 3.6 硬要求）。
///
/// 三条硬规则：
/// 1. 文件落到**应用专属目录** `getApplicationDocumentsDirectory()/diary_media/`；
/// 2. **数据库只存相对路径**（`diary_media/xxx.jpg`），绝不存绝对路径 ——
///    沙盒路径在重装 / 换机 / iOS 容器迁移后会变，存绝对路径等于埋死链；
/// 3. 图片进入应用后**复制一份**，不引用相册原文件 —— 相册里删掉原图，日记里的图还在。
///
/// 这个类只依赖 `dart:io` + `path_provider`，不碰 Flutter widget；
/// 测试时用 [DiaryMediaStore.withRoot] 注入临时目录，就能在纯 Dart 测试里跑。
class DiaryMediaStore {
  DiaryMediaStore.withRoot(this.root);

  /// 应用文档目录（测试里传临时目录）
  final Directory root;

  static const String folderName = 'diary_media';

  /// 打开真实存储：应用文档目录下的 `diary_media/`，不存在则创建。
  static Future<DiaryMediaStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final store = DiaryMediaStore.withRoot(docs);
    await store.folder.create(recursive: true);
    return store;
  }

  Directory get folder => Directory(p.join(root.path, folderName));

  /// 把外部文件复制进应用目录，返回**相对路径**（落库的就是它）。
  ///
  /// 文件名用「时间戳 + 随机数」，避免同名覆盖；扩展名保留原样（白名单之外一律 `.jpg`，
  /// 防止 `.svg`/可执行后缀被写进来当作图片渲染）。
  Future<String> importFile(String sourcePath) async {
    await folder.create(recursive: true);
    final rawExt = p.extension(sourcePath).toLowerCase();
    final ext = _allowedExtensions.contains(rawExt) ? rawExt : '.jpg';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    final name = '${stamp}_$rnd$ext';
    final target = File(p.join(folder.path, name));
    await File(sourcePath).copy(target.path);
    return '$folderName/$name';
  }

  /// 相对路径 → 真实文件（渲染时用）
  File fileFor(String relativePath) => File(p.join(root.path, relativePath));

  bool exists(String relativePath) => fileFor(relativePath).existsSync();

  /// 删除一张图片（日记被删/图片被移除时调用；文件不存在不报错）
  Future<void> remove(String relativePath) async {
    final file = fileFor(relativePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  static const Set<String> _allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
  };
}

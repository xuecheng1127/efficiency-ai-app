import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/app_database.dart';
import '../task/data/task_repository_impl.dart';

/// 启动页（模块5 P0）
///
/// 规则：
/// - 冷启动显示 Logo，固定保底 2 秒；
/// - 数据未加载完成则自动延长，加载完毕立即跳转；
/// - 数据库损坏时显示错误页，提供「重试」和「备份并重建」。
class SplashPage extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const SplashPage({super.key, required this.onDone});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

enum _BootState { loading, failed, ready }

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _navigated = false;
  _BootState _state = _BootState.loading;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 800));
    await _tryOpen();
  }

  Future<void> _tryOpen() async {
    try {
      final db = AppDatabase.instance;
      // 真读一次，拦住坏文件
      await db.customSelect('SELECT 1').get();
      final repo = TaskRepositoryImpl(db);
      await repo.backfillOnAppStart(DateTime.now());
      if (!mounted) return;
      setState(() => _state = _BootState.ready);
      _navigate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _BootState.failed;
        _errorMsg = '本地数据库无法打开，可能是文件损坏或存储空间不足。';
      });
    }
  }

  /// 备份坏库并新建空库
  Future<void> _rebuild() async {
    final log = <String>[];
    try {
      // 1. 先关连接，释放文件句柄（坏库 close 也可能抛异常，容错）
      try {
        await AppDatabase.instance.close();
        log.add('close: ok');
      } catch (e) {
        log.add('close: ${e.toString().split("\n").first}');
      }
      AppDatabase.resetInstance();

      // 2. 逐个处理数据库文件：优先 rename，失败则 copy+delete 兜底
      final dir = await getApplicationSupportDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File(p.join(dir.path, 'efficiency_app.sqlite$suffix'));
        if (!await f.exists()) {
          log.add('$suffix: absent');
          continue;
        }
        final dst = p.join(dir.path, 'efficiency_app.sqlite.corrupt-$ts$suffix');
        try {
          await f.rename(dst);
          log.add('$suffix: renamed');
        } catch (e1) {
          // Android(POSIX) 下 delete 对已打开的文件也有效，先备份再删
          try {
            await f.copy(dst);
            await f.delete();
            log.add('$suffix: copied+deleted');
          } catch (e2) {
            log.add('$suffix: FAIL ${e1.toString().split("\n").first} / ${e2.toString().split("\n").first}');
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _state = _BootState.loading;
        _errorMsg = '';
      });

      // 3. 重开（此时应新建空库）
      await _tryOpen();

      // 4. 若仍然失败，把详细日志显示出来，便于定位（不再吞掉）
      if (mounted && _state == _BootState.failed) {
        setState(() => _errorMsg = '重建后仍无法打开数据库。详情：\n${log.join("\n")}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = '备份失败：$e\n${log.join("\n")}');
    }
  }

  void _navigate() {
    if (_navigated) return;
    _navigated = true;
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_state == _BootState.failed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('启动失败', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_errorMsg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        setState(() => _state = _BootState.loading);
                        try { await AppDatabase.instance.close(); } catch (_) {}
                        AppDatabase.resetInstance();
                        await _tryOpen();
                      },
                      child: const Text('重新尝试'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: _rebuild,
                      child: const Text('备份并重建'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 52),
            ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: AppMotion.easeOutCubic,
                ).fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            const Text('效率助手', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700))
                .animate().fadeIn(duration: 600.ms, delay: 200.ms),
            const SizedBox(height: 8),
            Text('专注 · 记录 · 成长', style: TextStyle(fontSize: 13, color: (isDark ? AppColors.textDark : AppColors.textLight).withValues(alpha: 0.6)))
                .animate().fadeIn(duration: 600.ms, delay: 350.ms),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

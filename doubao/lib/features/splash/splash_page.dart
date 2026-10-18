import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/database/app_database.dart';
import '../task/data/task_repository_impl.dart';

/// 启动页（模块5 P0）
///
/// 规则：
/// - 冷启动显示 Logo，固定保底 2 秒；
/// - 数据未加载完成则自动延长，加载完毕立即跳转；
/// - 热启动/从后台切回不显示启动页（由路由层控制，见 main_shell）。
class SplashPage extends ConsumerStatefulWidget {
  /// 数据就绪后的跳转回调（由外部路由决定跳转到主框架）
  final VoidCallback onDone;

  const SplashPage({super.key, required this.onDone});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 保底 3 秒后必须跳转（P0：splash 不得卡死）
    // backfill 在后台 fire-and-forget，不阻塞 UI 跳转；
    // 主页 provider 用 Stream.watch 会在数据就绪后自动刷新。
    // ignore: discarded_futures
    _initDatabaseAndBackfill();
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    _navigate();
  }

  /// 打开 Drift 数据库并执行启动时惰性补齐（规格 §3：应用启动/回前台补齐）
  /// 所有异常吞掉：数据库问题不应阻塞启动（主页 provider 会报错展示空态）
  Future<void> _initDatabaseAndBackfill() async {
    try {
      final db = AppDatabase.instance;
      await db.customSelect('SELECT 1').get();
      final repo = TaskRepositoryImpl(db);
      await repo.backfillOnAppStart(DateTime.now());
      // T10: 启动时读回已调度闹钟，证明从表读回（非内存/Intent）
      final alarms = await db.select(db.scheduledAlarms).get();
      // ignore: avoid_print
      print('[Splash] T10 readback: ${alarms.length} scheduled alarm(s) from DB');
      for (final a in alarms) {
        // ignore: avoid_print
        print('[Splash]   taskId=${a.taskId} ${a.hour}:${a.minute} '
            'rule=${a.repeatRule} advance=${a.advanceMinutes}min '
            'ringtone=${a.ringtone} vol=${a.volume} snooze=${a.snoozeEnabled}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Splash] backfill non-fatal: $e');
    }
  }

  void _navigate() {
    if (_navigated) return;
    _navigated = true;
    // 不使用 addPostFrameCallback：vivo V2309A 上 Impeller 首帧 Surface=0 时
    // postFrameCallback 不触发，导致 splash 永久卡死（Bug 报告 §5.3）。
    // 直接调 onDone（内部 setState），与首帧渲染解耦。
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo 占位（V1.0 使用文字 Logo，后续替换为设计资源）
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
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 52,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: AppMotion.easeOutCubic,
                )
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            const Text(
              '效率助手',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              '专注 · 记录 · 成长',
              style: TextStyle(
                fontSize: 13,
                color: (isDark ? AppColors.textDark : AppColors.textLight)
                    .withValues(alpha: 0.6),
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 350.ms),
          ],
        ),
      ),
    );
  }
}

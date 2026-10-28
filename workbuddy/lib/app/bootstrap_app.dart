import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_dimens.dart';
import '../core/database/app_boot.dart';
import '../core/database/app_database.dart';
import '../core/database/database_provider.dart';
import '../core/settings/app_settings.dart';
import 'app.dart';
import 'theme/app_theme.dart';

/// 启动引导：把「打开本地数据」这件事变成**有 UI 的状态机**。
///
/// 三态：
/// - 打开中：转圈 + 一句说明（不再是白屏）；
/// - 失败：可读原因 + 「重新尝试」+「备份数据库并重建」两个真入口；
/// - 成功：挂上 `ProviderScope` 进入正常应用。
///
/// 背景：`main()` 以前是「一路 await，任何一步抛异常就不 runApp」，
/// 数据库坏掉时用户只会看到一个停在 Flutter logo 的白屏，且**没有任何自救入口**。
/// 现在失败会被接住并如实呈现（HARDENING A4）。
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key, this.boot, this.quarantine});

  /// 测试可注入；为空时走真实启动流程。
  final BootFunction? boot;

  /// 测试可注入；为空时走「备份默认位置的数据库」。
  final QuarantineFunction? quarantine;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

typedef BootFunction = Future<BootResult> Function();
typedef QuarantineFunction = Future<File?> Function();

class _BootstrapAppState extends State<BootstrapApp> {
  BootResult? _result;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await (widget.boot ?? bootApp)();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// 备份损坏文件 → 重建空库 → 重新走一遍启动流程。
  ///
  /// [hostContext] 必须来自 MaterialApp **内部**（见 build 里的 Builder）：
  /// State.context 在 MaterialApp 之上，那里没有 Navigator / Localizations，
  /// `showDialog` 会直接抛 `No MaterialLocalizations found`。
  Future<void> _rebuild(BuildContext hostContext) async {
    final ok = await showDialog<bool>(
      context: hostContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('备份并重建数据库'),
        content: const Text(
          '损坏的文件会改名保留（不会删除），然后新建一个空库。\n\n'
          '重建后应用可以正常打开，但当前数据不再显示；'
          '旧文件仍在应用目录里，可后续人工找回。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('备份并重建'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await (widget.quarantine ?? AppDatabase.quarantineDefault)();
    } catch (e) {
      if (!mounted || !hostContext.mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(hostContext).showSnackBar(
        SnackBar(content: Text('备份失败，未做任何改动：$e')),
      );
      return;
    }
    if (!mounted) return;
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return ProviderScope(
        // 重建后库对象是新的：换一个 key，避免沿用上一轮的 provider 缓存。
        key: ObjectKey(result.db),
        overrides: [
          databaseProvider.overrideWithValue(result.db),
          settingsStoreProvider.overrideWithValue(result.settings),
        ],
        child: const App(),
      );
    }

    return MaterialApp(
      title: '效率',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // Builder 的意义：拿到 MaterialApp 内部的 context（带 Navigator/本地化），
      // 弹确认框、弹 SnackBar 都必须基于它。
      home: Builder(
        builder: (innerContext) => _loading
            ? const _BootingView()
            : _BootFailedView(
                error: _error,
                onRetry: _start,
                onRebuild: () => _rebuild(innerContext),
              ),
      ),
    );
  }
}

/// 打开中：不是白屏，明确告诉用户在等什么。
class _BootingView extends StatelessWidget {
  const _BootingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppDimens.cardGap),
            Text(
              '正在打开本地数据…',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 启动失败：说明发生了什么 + 两条自救路径。
class _BootFailedView extends StatelessWidget {
  const _BootFailedView({
    required this.error,
    required this.onRetry,
    required this.onRebuild,
  });

  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onRebuild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = _readable(error);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.storage_outlined,
                size: 44,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                '本地数据打不开',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '应用没能读取本机的数据库文件，所以没有进入主界面。\n'
                '你的数据没有被自动删除。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                ),
                child: SelectableText(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新尝试'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRebuild,
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text('备份数据库并重建'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '「重建」只会把损坏的文件改名保留（…sqlite.corrupt-时间戳），'
                '再新建一个空库；旧文件不会被删除。',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 异常 → 一句人话（去掉 `Exception:` 前缀，过长截断，保留关键信息）。
  ///
  /// SQLite 的原文长这样：`SqliteException(26): while selecting …, file is not a
  /// database, SQL logic error (code 26)`。直接贴出来前半句是「SQLite 26): while …」，
  /// 很难读，所以把异常类型改写成「SQLite 错误码 26」。
  static String _readable(Object? error) {
    if (error == null) return '未知错误';
    final raw = error
        .toString()
        .replaceFirst('Exception: ', '')
        // 注意：String.replaceFirst 的替换串**不做**分组展开（`$1` 会原样输出），
        // 所以要拿错误码必须走 replaceAllMapped。
        .replaceAllMapped(
          RegExp(r'SqliteException\((\d+)\)'),
          (m) => 'SQLite 错误码 ${m[1]}',
        )
        .replaceFirst(RegExp(r'\s+'), ' ')
        .trim();
    if (raw.isEmpty) return error.runtimeType.toString();
    return raw.length > 300 ? '${raw.substring(0, 300)}…' : raw;
  }
}

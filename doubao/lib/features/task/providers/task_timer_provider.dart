import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/services/task_timer_service.dart';
import 'task_providers.dart';

part 'task_timer_provider.freezed.dart';

/// 任务计时状态（不可变状态类，freezed 生成）
///
/// occurrenceId == -1 表示当前无计时任务（空闲态）。
@freezed
abstract class TaskTimerState with _$TaskTimerState {
  const TaskTimerState._();

  const factory TaskTimerState({
    /// 当前计时中的任务实例 id；-1 表示空闲
    @Default(-1) int occurrenceId,

    /// 任务标题（通知栏/横幅展示）
    @Default('') String title,

    /// 本次计时起点（数据库 startedAt，持久化保证跨启动恢复）
    DateTime? startedAt,

    /// 本次计时开始前已累计秒数（数据库 durationSeconds 快照）
    @Default(0) int baseSeconds,

    /// 最新累计秒数（baseSeconds + 已流逝秒，每秒心跳刷新）
    @Default(0) int elapsedSeconds,

    /// 前台服务是否已启动
    @Default(false) bool serviceStarted,
  }) = _TaskTimerState;

  /// 是否空闲（无计时任务）
  bool get idle => occurrenceId == -1;

  /// 是否正在计时
  bool get active => !idle && startedAt != null;

  /// 格式化耗时（mm:ss / hh:mm:ss）
  String get formattedElapsed {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// 任务计时控制器（模块1 P0 计时器核心编排）
///
/// 职责：
/// - 协调「前台服务 + 数据库 + 每秒心跳」三方状态；
/// - 开始计时：写库（inProgress + startedAt）→ 启动前台服务 → 启动心跳；
/// - 暂停/完成：停止心跳与服务 → 计算 elapsed → 回填数据库耗时；
/// - 监听通知栏按钮事件（暂停/完成），与页面操作走同一套流转。
class TaskTimerNotifier extends Notifier<TaskTimerState> {
  Timer? _tick;

  /// 前台服务数据回调（通知栏按钮/心跳转发主 isolate）
  late final void Function(Object?) _onServiceData;

  @override
  TaskTimerState build() {
    // 注册前台服务数据回调：通知栏「暂停/完成」按钮事件
    _onServiceData = (Object? data) {
      if (data is! Map) return;
      final type = data['type'];
      if (type == 'button') {
        final action = data['action'];
        if (action == TaskTimerService.buttonPause) {
          _pauseCurrent();
        } else if (action == TaskTimerService.buttonComplete) {
          _completeCurrent();
        }
      }
    };
    TaskTimerService.instance.addDataListener(_onServiceData);
    ref.onDispose(() {
      TaskTimerService.instance.removeDataListener(_onServiceData);
      _tick?.cancel();
    });
    return const TaskTimerState();
  }

  // ==================== 对外操作 ====================

  /// 开始计时（点击卡片「开始」）
  ///
  /// [occurrenceId] 任务实例 id；[title] 任务标题。
  /// 数据库 startedAt 已由调用方写入，此处以库中值为计时基准。
  Future<void> start({
    required int occurrenceId,
    required String title,
  }) async {
    // 若已有任务在计时，先完成旧的（防御：只允许同时计时一个任务）
    if (!state.idle && state.occurrenceId != occurrenceId) {
      await _completeCurrent();
    }

    final repo = ref.read(taskRepositoryProvider);
    await repo.startTask(occurrenceId);

    // 读取库中的 startedAt 作为计时起点
    final occ = await repo.getOccurrenceById(occurrenceId);
    final startedAt = occ?.startedAt;
    if (startedAt == null) return; // 防御：未写库成功则不启动

    final base = occ?.accumulatedSeconds ?? 0;
    state = TaskTimerState(
      occurrenceId: occurrenceId,
      title: title,
      startedAt: startedAt,
      baseSeconds: base,
      elapsedSeconds: _computeElapsed(startedAt, base),
      serviceStarted: true,
    );

    // 启动前台服务（后台计时保活，退出应用不中断）
    await TaskTimerService.instance.start(
      occurrenceId: occurrenceId,
      title: title,
      startedAt: startedAt,
      baseSeconds: base,
    );

    _startTick();
  }

  /// 暂停计时（回到未完成，保留已累计耗时）
  Future<void> pause() async {
    await _pauseCurrent();
  }

  /// 完成计时（归档耗时，切为已完成）
  Future<void> complete() async {
    await _completeCurrent();
  }

  // ==================== 内部实现 ====================

  /// 每秒心跳：刷新 elapsedSeconds，驱动横幅/卡片实时刷新
  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (!s.active) return;
      state = s.copyWith(
        elapsedSeconds: _computeElapsed(s.startedAt!, s.baseSeconds),
      );
    });
  }

  /// 暂停当前计时任务
  Future<void> _pauseCurrent() async {
    final s = state;
    if (s.idle) return;

    _stopTimerAndService();

    final repo = ref.read(taskRepositoryProvider);
    // 回填本次计时耗时：elapsedSeconds 已含 baseSeconds，
    // 仓库层为增量语义（durationSeconds += elapsed），传已流逝部分
    final liveSeconds = _liveSeconds(s);
    await repo.pauseTask(s.occurrenceId, elapsedSeconds: liveSeconds);

    state = const TaskTimerState();
  }

  /// 完成当前计时任务
  Future<void> _completeCurrent() async {
    final s = state;
    if (s.idle) return;

    _stopTimerAndService();

    final repo = ref.read(taskRepositoryProvider);
    final liveSeconds = _liveSeconds(s);
    await repo.completeTask(s.occurrenceId, extraSeconds: liveSeconds);

    state = const TaskTimerState();
  }

  /// 停止心跳 + 停止前台服务（状态稍后由调用方重置）
  void _stopTimerAndService() {
    _tick?.cancel();
    _tick = null;
    // 异步停止服务，不阻塞状态流转
    TaskTimerService.instance.stop();
  }

  /// 本次计时的「已流逝秒数」（不含 baseSeconds，供增量回填）
  int _liveSeconds(TaskTimerState s) {
    if (!s.active) return 0;
    final delta = DateTime.now().difference(s.startedAt!).inSeconds;
    return delta > 0 ? delta : 0;
  }

  /// 累计秒数 = baseSeconds + 已流逝秒数
  int _computeElapsed(DateTime startedAt, int baseSeconds) {
    final delta = DateTime.now().difference(startedAt).inSeconds;
    return baseSeconds + (delta > 0 ? delta : 0);
  }
}

/// 任务计时 Provider（全局唯一，跨页面共享）
final taskTimerProvider =
    NotifierProvider<TaskTimerNotifier, TaskTimerState>(
  TaskTimerNotifier.new,
);

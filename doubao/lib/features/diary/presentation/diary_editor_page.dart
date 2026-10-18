import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../task/providers/task_providers.dart';
import '../providers/diary_providers.dart';

/// 日记编辑器（T22）
///
/// 内容防丢失三重保护：
/// 1. 每 10 秒自动保存到 Drift
/// 2. AppLifecycleState.paused/inactive 时立即保存（切后台/锁屏）
/// 3. 每次 onChanged 写 SharedPreferences 草稿，force-stop 后重开可恢复
class DiaryEditorPage extends ConsumerStatefulWidget {
  final int? diaryId;
  const DiaryEditorPage({super.key, this.diaryId});

  @override
  ConsumerState<DiaryEditorPage> createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends ConsumerState<DiaryEditorPage>
    with WidgetsBindingObserver {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  Timer? _autoSaveTimer;

  bool _isLined = true;
  double _fontSize = 16.0;
  int? _diaryId;
  bool _dirty = false;
  bool _loaded = false;
  bool _autoSummary = false;
  bool _summaryInserted = false;

  String get _draftKey => 'diary_draft_${_diaryId ?? "new"}';

  @override
  void initState() {
    super.initState();
    _diaryId = widget.diaryId;
    WidgetsBinding.instance.addObserver(this);
    _load();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _save());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _save();
    _clearDraft();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切后台/锁屏/来电时立即保存，覆盖"切后台再被杀"
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _save();
      _writeDraft();
    }
  }

  Future<void> _load() async {
    if (_diaryId != null) {
      final repo = ref.read(diaryRepositoryProvider);
      final d = await repo.getById(_diaryId!);
      if (d != null && mounted) {
        _titleCtrl.text = d.title;
        _contentCtrl.text = d.content;
        _isLined = d.templateType == 'lined';
        _fontSize = d.fontSize;
      }
    }
    // 检查草稿：force-stop 后重开时恢复
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(_draftKey);
    if (draft != null && draft.isNotEmpty && mounted) {
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('检测到未保存的草稿'),
          content: const Text('上次有未保存的内容，要恢复吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('放弃'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复'),
            ),
          ],
        ),
      );
      if (shouldRestore == true && mounted) {
        _contentCtrl.text = draft;
        _dirty = true;
      }
    }
    if (mounted) setState(() => _loaded = true);
    // 读取自动总结开关
    final prefs0 = await SharedPreferences.getInstance();
    _autoSummary = prefs0.getBool('diary_auto_summary') ?? false;
  }

  Future<void> _insertSummaryIfNeeded() async {
    if (_summaryInserted || !_autoSummary) return;
    _summaryInserted = true;
    final tasks = ref.read(todayTasksProvider).valueOrNull ?? [];
    final done = tasks.where((t) => t.occurrence.status.name == 'done').toList();
    if (done.isEmpty) return;
    final buf = StringBuffer()
      ..writeln('📊 今日完成 ${done.length} 件事');
    for (final t in done) {
      buf.writeln('✅ ${t.occurrence.titleSnapshot}');
    }
    buf.writeln();
    final existing = _contentCtrl.text;
    _contentCtrl.text = existing.isEmpty
        ? buf.toString()
        : '$existing\n${buf.toString()}';
    _dirty = true;
  }

  Future<void> _save() async {
    if (!_dirty) return;
    final repo = ref.read(diaryRepositoryProvider);
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    _diaryId = await repo.upsert(
      id: _diaryId,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text,
      templateType: _isLined ? 'lined' : 'blank',
      fontSize: _fontSize,
      diaryDate: dayStart.millisecondsSinceEpoch,
    );
    _dirty = false;
    _clearDraft();
  }

  Future<void> _writeDraft() async {
    if (_contentCtrl.text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, _contentCtrl.text);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 首次构建后自动插入今日总结
    WidgetsBinding.instance.addPostFrameCallback((_) => _insertSummaryIfNeeded());
    return Scaffold(
      appBar: AppBar(
        title: const Text('写日记'),
        actions: [
          // 自动总结开关
          Row(
            children: [
              const Text('自动总结', style: TextStyle(fontSize: 12)),
              Switch(
                value: _autoSummary,
                onChanged: (v) async {
                  setState(() => _autoSummary = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('diary_auto_summary', v);
                  if (v) _insertSummaryIfNeeded();
                },
              ),
            ],
          ),
          IconButton(
            icon: Icon(_isLined ? Icons.horizontal_rule : Icons.border_clear),
            onPressed: () => setState(() => _isLined = !_isLined),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _showFontSizePicker,
          ),
        ],
      ),
      body: _isLined
          ? CustomPaint(
              painter: _LinePainter(
                lineSpacing: _fontSize * 1.5,
                topPadding: 16,
              ),
              child: SizedBox.expand(child: _buildTextField()),
            )
          : Container(
              color: Colors.white,
              child: SizedBox.expand(child: _buildTextField()),
            ),
    );
  }

  Widget _buildTextField() {
    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: _contentCtrl,
        maxLines: null,
        expands: true,
        autofocus: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          hintText: '今天发生了什么...',
          border: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.all(16),
        ),
        style: TextStyle(fontSize: _fontSize, height: 1.5),
        onChanged: (v) {
          _dirty = true;
          _writeDraft();
        },
      ),
    );
  }

  void _showFontSizePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('字号: ${_fontSize.toStringAsFixed(0)}'),
              Slider(
                min: 12,
                max: 32,
                value: _fontSize,
                onChanged: (v) {
                  setSheet(() => _fontSize = v);
                  setState(() {});
                  _dirty = true;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 横线本画线 painter：横线间距 = 字号 × 1.5，与文字行高对齐
class _LinePainter extends CustomPainter {
  final double lineSpacing;
  final double topPadding;
  _LinePainter({required this.lineSpacing, required this.topPadding});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF8FAFC));
    final paint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1;
    var y = topPadding + lineSpacing;
    while (y < size.height) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), paint);
      y += lineSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.lineSpacing != lineSpacing ||
      oldDelegate.topPadding != topPadding;
}

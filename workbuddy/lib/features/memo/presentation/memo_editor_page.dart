import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../domain/memo.dart';
import '../providers/memo_providers.dart';

/// 备忘编辑页（规格 §3.2 / §3.3）。
///
/// 极低摩擦的三条硬约束：
/// 1. **没有必填项** —— 进来就能写，光标自动在输入框里（[autofocus]）；
/// 2. **空内容不保存** —— 防止列表里出现一条点不开的空卡片；
/// 3. **有改动才写库** —— 返回时自动保存，没改就什么都不做。
class MemoEditorPage extends ConsumerStatefulWidget {
  const MemoEditorPage({super.key, this.memoId = 0});

  /// 0 = 新建
  final int memoId;

  @override
  ConsumerState<MemoEditorPage> createState() => _MemoEditorPageState();
}

class _MemoEditorPageState extends ConsumerState<MemoEditorPage> {
  final TextEditingController _ctrl = TextEditingController();

  int _savedId = 0;
  bool _loading = true;
  bool _saving = false;
  bool _pinned = false;
  String? _color;

  String _lastSaved = '';

  bool get _dirty => _ctrl.text != _lastSaved;

  @override
  void initState() {
    super.initState();
    _savedId = widget.memoId;
    _load();
  }

  Future<void> _load() async {
    if (widget.memoId <= 0) {
      setState(() => _loading = false);
      return;
    }
    final memo = await ref.read(memoRepositoryProvider).findById(widget.memoId);
    if (!mounted) return;
    if (memo != null) {
      _ctrl.text = memo.content;
      _lastSaved = memo.content;
      _pinned = memo.pinned;
      _pinnedSaved = memo.pinned;
      _color = memo.color;
      _savedId = memo.id;
    }
    setState(() => _loading = false);
  }

  /// 保存：返回 true 表示"有内容被写入"
  Future<bool> _save() async {
    if (_saving) return false;
    final content = _ctrl.text;
    // 规格 §3.3：空内容不保存（新建直接丢弃；已有备忘被清空时保留原内容）
    if (content.trim().isEmpty) return false;
    if (_savedId > 0 && !_dirty && _pinned == _pinnedSaved) return false;

    _saving = true;
    try {
      final repo = ref.read(memoRepositoryProvider);
      if (_savedId == 0) {
        _savedId = await repo.create(
          content: content,
          pinned: _pinned,
          color: _color,
        );
      } else {
        await repo.update(
          _savedId,
          content: content,
          pinned: _pinned,
          color: _color,
        );
      }
      _lastSaved = content;
      _pinnedSaved = _pinned;
      return true;
    } finally {
      _saving = false;
    }
  }

  /// 已经落库的置顶态（避免「只改了置顶」被判成没改动）
  bool _pinnedSaved = false;

  Future<void> _leave() async {
    await _save();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    if (_savedId == 0) {
      // 新建但还没落库：直接退出即可，没有可删的东西
      Navigator.of(context).pop(true);
      return;
    }
    final ok = await _confirmDelete(context);
    if (ok != true) return;
    await ref.read(memoRepositoryProvider).softDelete(_savedId);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回并保存',
            icon: const Icon(Icons.arrow_back),
            onPressed: _leave,
          ),
          title: Text(_savedId == 0 ? '新建备忘' : '编辑备忘'),
          actions: [
            IconButton(
              tooltip: _pinned ? '取消置顶' : '置顶',
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
              color: _pinned ? theme.colorScheme.primary : null,
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            TextButton(
              // 规格 §3.3：保存后**立刻回到列表**并看到新卡片。
              // 所以这里保存成功就直接 pop；只有"内容为空"才留在原地提示。
              onPressed: () async {
                final ok = await _save();
                if (!mounted) return;
                if (ok) {
                  Navigator.of(context).pop(true);
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('内容为空，未保存'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Text('保存'),
            ),
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  4,
                  AppDimens.pagePadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildColors(theme),
                    const SizedBox(height: 4),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true, // 规格 §3.2：自动聚焦
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                        decoration: const InputDecoration.collapsed(
                          hintText: '记点什么…',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// 纸色选择：4 个圆点，点了立刻生效（保存时随内容一起落库）
  Widget _buildColors(ThemeData theme) {
    return Row(
      children: [
        Text(
          '纸色',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        for (final c in MemoColor.all)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: memoPaperColor(theme, c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _color == c
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: _color == c ? 2 : 1,
                  ),
                ),
                child: _color == c
                    ? Icon(
                        Icons.check,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// 纸色 → 实际颜色（默认纸色跟随主题）
Color memoPaperColor(ThemeData theme, String? color) {
  switch (color) {
    case MemoColor.yellow:
      return theme.brightness == Brightness.dark
          ? const Color(0xFF4A422A)
          : const Color(0xFFFFF6D6);
    case MemoColor.blue:
      return theme.brightness == Brightness.dark
          ? const Color(0xFF243A4A)
          : const Color(0xFFE3F1FB);
    case MemoColor.green:
      return theme.brightness == Brightness.dark
          ? const Color(0xFF2A4231)
          : const Color(0xFFE6F5E9);
    default:
      return theme.colorScheme.surfaceContainerLow;
  }
}

/// 删除确认（列表页与编辑页共用同一套文案，避免两处说法不一致）
Future<bool?> _confirmDelete(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除备忘'),
      content: const Text('删除后列表里会消失，不会同步到别处。确定删除吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('删除'),
        ),
      ],
    ),
  );
}

/// 暴露给列表页复用
Future<bool?> confirmDeleteMemo(BuildContext context) =>
    _confirmDelete(context);

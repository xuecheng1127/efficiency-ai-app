import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_dimens.dart';
import '../data/diary_media_store.dart';
import '../domain/diary_block.dart';
import '../domain/diary_entry.dart';
import '../engine/cjk_layout.dart';
import '../providers/diary_providers.dart';
import 'widgets/lined_paper.dart';

/// 日记编辑器。
///
/// - 横线本 / 空白本切换**立即生效**；
/// - 字号 12–32，**行高 = 字号 × 1.5**（由排版引擎的 `lineHeightFor` 给出，横线也按它画）；
/// - **每 30 秒自动保存** + 退出页面保存（PopScope 拦截，先存再退）；
/// - 键盘弹出时编辑区自动上移（`expands` 的 TextField + Scaffold 默认 resize）。
class DiaryEditorPage extends ConsumerStatefulWidget {
  const DiaryEditorPage({super.key, required this.diaryId});

  /// 0 = 新建
  final int diaryId;

  @override
  ConsumerState<DiaryEditorPage> createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends ConsumerState<DiaryEditorPage> {
  /// 排版引擎：本页只借它算行高/行距，断行能力由单测覆盖（纯 Dart）。
  static final CjkLayoutEngine _engine = CjkLayoutEngine();

  final TextEditingController _titleCtrl = TextEditingController();

  final TextEditingController _bodyCtrl = TextEditingController();

  /// 预览模式：把 `[[img:...]]` 标记渲染成占满整行的图片块（所见即所得）
  bool _preview = false;

  /// 图片存储（异步打开；未就绪时插入图片会先等它）
  DiaryMediaStore? _media;

  Timer? _autoSaveTimer;
  int _savedId = 0;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  DateTime? _lastSavedAt;
  String _templateType = DiaryTemplateType.lined;
  double _fontSize = 16;
  String _lastSavedTitle = '';
  String _lastSavedBody = '';

  double get _lineHeight => _engine.lineHeightFor(_fontSize);

  @override
  void initState() {
    super.initState();
    _savedId = widget.diaryId;
    _titleCtrl.addListener(_markDirty);
    _bodyCtrl.addListener(_markDirty);
    // 每 30 秒自动保存一次（PRD 硬要求）
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _save(auto: true),
    );
    _load();
    _openMediaStore();
  }

  Future<void> _openMediaStore() async {
    final store = await ref.read(diaryMediaStoreProvider.future);
    if (!mounted) return;
    setState(() => _media = store);
  }

  /// 插入图片（P0 核心路径之外，规格 §1「块级排布」的最小实现）。
  ///
  /// 流程：相册选图 → **复制**到应用目录 → 正文插入一行标记 → **立刻保存**。
  /// 立刻保存这一步是刻意的：插入图片是一件「用户完成了一个动作」的事，
  /// 不该等 30 秒定时器；强杀重启后图片必须还在（验收第 5 条）。
  Future<void> _pickImage() async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 88,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打不开相册：$e')));
      return;
    }
    if (picked == null) return; // 用户取消，不是错误

    final DiaryMediaStore store =
        _media ?? await ref.read(diaryMediaStoreProvider.future);
    if (!mounted) return;
    setState(() => _media = store);

    String relativePath;
    try {
      relativePath = await store.importFile(picked.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片保存失败：$e')));
      return;
    }
    if (!mounted) return;
    _insertMarker(DiaryBlocks.markerFor(relativePath));
    await _save();
  }

  /// 把图片标记插到光标处，并保证它**独占一行**（解析器只认整行标记）
  void _insertMarker(String marker) {
    final text = _bodyCtrl.text;
    final sel = _bodyCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final before = text.substring(0, start);
    final after = text.substring(end);
    final prefix = (before.isEmpty || before.endsWith('\n')) ? '' : '\n';
    final snippet = '$prefix$marker\n';
    final next = '$before$snippet$after';
    _bodyCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: before.length + snippet.length,
      ),
    );
    _markDirty();
  }

  /// 删掉一张图片：先从正文移除标记，文件只在「没有任何日记再引用」时删除。
  ///
  /// 注意这里只删当前这条日记自己的引用；跨日记共享文件的情况 V1.0 不存在
  /// （每次插入都是一次复制，文件名唯一），所以从正文移除即可安全删文件。
  Future<void> _removeImage(String relativePath) async {
    final marker = DiaryBlocks.markerFor(relativePath);
    final lines = _bodyCtrl.text.split('\n');
    final kept = <String>[];
    var removed = false;
    for (final line in lines) {
      if (!removed && line.trim() == marker) {
        removed = true;
        continue;
      }
      kept.add(line);
    }
    if (!removed) return;
    _bodyCtrl.text = kept.join('\n');
    _markDirty();
    await _save();
    await _media?.remove(relativePath);
  }

  Future<void> _load() async {
    if (widget.diaryId <= 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final entry = await ref
        .read(diaryRepositoryProvider)
        .findById(widget.diaryId);
    if (!mounted) return;
    if (entry != null) {
      _titleCtrl.text = entry.title;
      _bodyCtrl.text = entry.content;
      _templateType = entry.templateType;
      _fontSize = entry.fontSize;
      _lastSavedTitle = entry.title;
      _lastSavedBody = entry.content;
      _savedId = entry.id;
      _dirty = false;
      // 从库里读出来的内容本来就是"已保存"状态，状态栏不该显示"尚未保存"
      _lastSavedAt = entry.updatedAt;
    }
    setState(() => _loading = false);
  }

  void _markDirty() {
    final changed =
        _titleCtrl.text != _lastSavedTitle || _bodyCtrl.text != _lastSavedBody;
    if (changed != _dirty) {
      setState(() => _dirty = changed);
    }
  }

  /// 保存。`auto: true` 表示自动保存（内容为空且是新建时不落库，避免产生空日记）。
  Future<void> _save({bool auto = false}) async {
    if (_saving) return;
    if (!_dirty && _savedId > 0) return;

    final title = _titleCtrl.text;
    final body = _bodyCtrl.text;

    // 新建 + 全空 → 不保存（不留空日记；这也符合"防脏数据"的直觉）
    if (_savedId == 0 && title.trim().isEmpty && body.trim().isEmpty) {
      return;
    }

    _saving = true;
    try {
      final repo = ref.read(diaryRepositoryProvider);
      if (_savedId == 0) {
        _savedId = await repo.create(
          title: title,
          content: body,
          templateType: _templateType,
          fontSize: _fontSize,
        );
      } else {
        await repo.update(
          _savedId,
          title: title,
          content: body,
          templateType: _templateType,
          fontSize: _fontSize,
        );
      }
      if (!mounted) return;
      setState(() {
        _lastSavedTitle = title;
        _lastSavedBody = body;
        _dirty = false;
        _lastSavedAt = DateTime.now();
      });
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
        );
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _leave() async {
    // 退出前强制保存（有改动才写）
    await _save();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    // 兜底：即便有路径绕过 PopScope，dispose 时也补一次保存（不 await）
    unawaited(_save());
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
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
          title: Text(_savedId == 0 ? '写日记' : '编辑日记'),
          leading: IconButton(
            tooltip: '返回并保存',
            icon: const Icon(Icons.arrow_back),
            onPressed: _leave,
          ),
          actions: [
            if (!_preview)
              IconButton(
                tooltip: '插入图片',
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: _pickImage,
              ),
            IconButton(
              tooltip: _preview ? '继续编辑' : '预览排版',
              icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _preview = !_preview),
            ),
            TextButton(
              onPressed: _dirty ? () => _save() : null,
              child: const Text('保存'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildToolbar(theme),
                  const Divider(height: 1),
                  Expanded(child: _buildPaperEditor(theme)),
                  _buildStatusBar(theme),
                ],
              ),
      ),
    );
  }

  /// 工具栏：模板切换 + 字号 + 行高提示（行高来自排版引擎）
  Widget _buildToolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        10,
        AppDimens.pagePadding,
        10,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: DiaryTemplateType.lined,
                    label: Text('横线本'),
                    icon: Icon(Icons.format_align_left, size: 16),
                  ),
                  ButtonSegment(
                    value: DiaryTemplateType.blank,
                    label: Text('空白本'),
                    icon: Icon(Icons.crop_square, size: 16),
                  ),
                ],
                selected: {_templateType},
                onSelectionChanged: (s) {
                  setState(() {
                    _templateType = s.first;
                    _dirty = true;
                  });
                },
              ),
              const Spacer(),
              Text(
                '行高 ${_lineHeight.toStringAsFixed(0)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                Icons.text_fields,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 12,
                  max: 32,
                  divisions: 20,
                  label: '${_fontSize.round()}',
                  onChanged: (v) {
                    setState(() {
                      _fontSize = v;
                      _dirty = true;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${_fontSize.round()}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 编辑区：横线本时用 CustomPaint 画线（行距 = 行高）
  Widget _buildPaperEditor(ThemeData theme) {
    const topPad = 8.0;
    final textStyle = TextStyle(
      fontSize: _fontSize,
      height: 1.5, // 行高 = 字号 × 1.5
      color: theme.colorScheme.onSurface,
    );

    return Stack(
      children: [
        if (_templateType == DiaryTemplateType.lined)
          Positioned.fill(
            child: CustomPaint(
              painter: LinedPaperPainter(
                lineHeight: _lineHeight,
                lineColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.45 : 0.7,
                ),
                topOffset: topPad + _lineHeight,
                horizontalPadding: AppDimens.pagePadding,
              ),
            ),
          ),
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              topPad,
              AppDimens.pagePadding,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_preview)
                  Text(
                    _titleCtrl.text.trim().isEmpty ? '无标题' : _titleCtrl.text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: _fontSize + 2,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: _titleCtrl.text.trim().isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  )
                else
                  TextField(
                    controller: _titleCtrl,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: _fontSize + 2,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration.collapsed(
                      hintText: '标题（可留空）',
                    ),
                  ),
                const SizedBox(height: 4),
                if (_preview)
                  _buildPreviewBlocks(theme, textStyle)
                else
                  TextField(
                    controller: _bodyCtrl,
                    // 多行自增长 + 键盘弹出时随 Scaffold 上移
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: textStyle,
                    decoration: const InputDecoration.collapsed(
                      hintText: '开始写…（插入的图片会在预览里占满整行）',
                    ),
                  ),
                const SizedBox(height: 160), // 给键盘/滚动留出尾部空间
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 预览：按块渲染（文字块上下流动，图片块占满整行）
  ///
  /// 为什么正文不直接内联在 TextField 里：Flutter 的 `TextField` + `WidgetSpan`
  /// 组合在 release 构建下实测会把同一段落里的普通文字整段吞掉（图片在、文字不渲染），
  /// 这是框架层面的坑，不是配置问题。V1.0 的正文字段就保持纯文本（规格 §2 也只要求纯文本），
  /// 图片用「块级预览」呈现 —— 编辑时看得到标记、预览时看到的是排好版的页面。
  Widget _buildPreviewBlocks(ThemeData theme, TextStyle base) {
    final blocks = DiaryBlocks.parse(_bodyCtrl.text);
    if (blocks.isEmpty) {
      return Text(
        '（空白）点右上角铅笔继续写',
        style: base.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          if (block is DiaryTextBlock)
            Text(block.text, style: base)
          else if (block is DiaryImageBlock)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _previewImage(theme, block.relativePath),
            ),
      ],
    );
  }

  Widget _previewImage(ThemeData theme, String relativePath) {
    final file = _media?.fileFor(relativePath) ?? File(relativePath);
    final height = (_lineHeight * 5).clamp(120.0, 280.0);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: file.existsSync()
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _missingImage(theme),
                  )
                : _missingImage(theme),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _removeImage(relativePath),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _missingImage(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            '图片已丢失',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    final saved = _lastSavedAt;
    final label = _dirty
        ? '有未保存的改动（30 秒自动保存）'
        : saved == null
        ? '尚未保存'
        : '已保存 ${_two(saved.hour)}:${_two(saved.minute)}:${_two(saved.second)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(
            _dirty ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
            size: 14,
            color: _dirty
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (_saving)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_dimens.dart';
import '../domain/diary_block.dart';
import '../domain/diary_entry.dart';
import '../engine/cjk_layout.dart';
import '../providers/diary_providers.dart';
import 'diary_editor_page.dart';
import 'widgets/cjk_preview_painter.dart';
import 'widgets/text_painter_measurer.dart';

/// 日记**预览页**（只读）—— 中文排版引擎的唯一出口。
///
/// ## 为什么要有这一页
///
/// 编辑器用 `TextField`，而 `TextField` 的换行在框架内部完成（`RenderEditable`），
/// 应用层拿不到断行决策点，所以「避头尾」在编辑态**做不到**（V1.0 已确认为此放弃
/// 了内联方案）。只读渲染则完全不同：整块文字可以由我们自己定行、定坐标。
///
/// 于是产品上分成两件事：
/// - **写** → 编辑器（`TextField`，原生换行，随手就写）；
/// - **看** → 本页（引擎断行 + 悬挂标点 + 字距挤压，排好版的样子）。
///
/// 列表点卡片进本页，右上角「编辑」再进编辑器；从编辑器回来会重新读库刷新。
class DiaryPreviewPage extends ConsumerStatefulWidget {
  const DiaryPreviewPage({super.key, required this.diaryId, this.initial});

  final int diaryId;

  /// 列表已有整条记录，先拿它渲染（避免白屏一帧）；为空则自行读库。
  final DiaryEntry? initial;

  @override
  ConsumerState<DiaryPreviewPage> createState() => _DiaryPreviewPageState();
}

class _DiaryPreviewPageState extends ConsumerState<DiaryPreviewPage> {
  static const double _topPad = 8;
  static const double _bottomPad = 48;

  DiaryEntry? _entry;
  bool _loading = true;

  /// 引擎**有状态**（段落缓存），必须是长生命周期对象：
  /// 每次 build 新建一个，增量重排就永远命中不了缓存。
  CjkLayoutEngine? _engine;
  String? _engineFontFamily;

  @override
  void initState() {
    super.initState();
    _entry = widget.initial;
    if (_entry != null) _loading = false;
    if (widget.initial == null) _load();
  }

  Future<void> _load() async {
    final entry = await ref
        .read(diaryRepositoryProvider)
        .findById(widget.diaryId);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _loading = false;
    });
  }

  /// 引擎按「字族」缓存：换字体必须换引擎，否则段落缓存里的行宽是旧字形的。
  CjkLayoutEngine _engineFor(String? fontFamily) {
    final current = _engine;
    if (current != null && _engineFontFamily == fontFamily) return current;
    final engine = CjkLayoutEngine(
      measurer: TextPainterGlyphMeasurer(
        baseStyle: TextStyle(fontFamily: fontFamily),
      ),
      lineHeightRatio: AppDimens.lineHeightRatio,
    );
    _engine = engine;
    _engineFontFamily = fontFamily;
    return engine;
  }

  Future<void> _openEditor() async {
    final entry = _entry;
    if (entry == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DiaryEditorPage(diaryId: entry.id)),
    );
    if (!mounted) return;
    // 编辑器可能改了正文/字号/模板，回来重新读一遍再排版。
    // 注意这里**不**调 engine.invalidateAll()：段落缓存按
    // （段落文本 + 宽度 + 字号 + 开关）匹配，改过的段落自然失配重排、没改的段落直接命中
    // —— 这正是「只重排受影响段落」，清掉缓存等于把增量能力扔掉。
    final fresh = await ref.read(diaryRepositoryProvider).findById(entry.id);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _entry = fresh;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = _entry;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日记预览'),
        actions: [
          TextButton.icon(
            onPressed: entry == null ? null : _openEditor,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('编辑'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : entry == null
          ? const _MissingView()
          : Column(
              children: [
                _Header(entry: entry),
                const Divider(height: 1),
                Expanded(child: _buildPaper(theme, entry)),
              ],
            ),
    );
  }

  /// 正文排版区：**一个** CustomPaint 承担「横线 + 全部文字」。
  Widget _buildPaper(ThemeData theme, DiaryEntry entry) {
    final text = DiaryBlocks.plainText(entry.content).trim();
    if (text.isEmpty) {
      return Center(
        child: Text(
          '（空白）点右上角「编辑」写点什么',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const left = AppDimens.pagePadding;
        final fontSize = entry.fontSize;
        final lineHeight = fontSize * AppDimens.lineHeightRatio;
        final baseStyle = TextStyle(fontFamily: entry.fontFamily);
        final textStyle = baseStyle.copyWith(
          fontSize: fontSize,
          height: AppDimens.lineHeightRatio,
          color: theme.colorScheme.onSurface,
        );

        // 右侧让出一个**全角**给悬挂标点：引擎把句号/逗号挂在行尾外侧且不计入
        // layoutWidth，如果不预留，那个标点会被画到屏幕边缘甚至被裁掉。
        final maxLineWidth = math.max(
          fontSize + 1,
          constraints.maxWidth - left * 2 - fontSize,
        );

        final engine = _engineFor(entry.fontFamily);
        final watch = Stopwatch()..start();
        final result = engine.layoutText(
          text: text,
          maxWidth: maxLineWidth,
          fontSize: fontSize,
        );
        watch.stop();
        final elapsedMs = watch.elapsedMicroseconds / 1000.0;

        // 真机性能证据：release 包里这条日志同样会打到 logcat（tag: flutter）。
        // 每次都打（而不是只在重排时打）—— 缓存全命中时 `laidOut=0 reused=4` 本身就是
        // 「增量重排生效」的证据，只打重排那一次就看不到它了。
        debugPrint(
          '[CjkPreview] chars=${text.length} lines=${result.lines.length} '
          'maxWidth=${maxLineWidth.toStringAsFixed(1)} '
          'layout=${elapsedMs.toStringAsFixed(1)}ms '
          'laidOut=${result.laidOutParagraphs} '
          'reused=${result.reusedParagraphs}',
        );

        final canvasHeight =
            _topPad + result.lines.length * lineHeight + _bottomPad;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          // CustomPaint 画出来的文字没有语义节点，读屏软件会读成一片空白。
          // 这里补一个整段 label：读屏 / UI 自动化都能拿到完整正文。
          child: Semantics(
            label: text,
            child: SizedBox(
              width: double.infinity,
              height: canvasHeight,
              child: CustomPaint(
                painter: CjkPreviewPainter(
                  lines: result.lines,
                  textStyle: textStyle,
                  lineHeight: lineHeight,
                  left: left,
                  right: constraints.maxWidth - left,
                  topPadding: _topPad,
                  lined: entry.isLined,
                  lineColor: theme.colorScheme.outlineVariant.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.45 : 0.7,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 页头：标题 + 日期/模板元信息（图片数量在这里提示，预览页只排版文字）。
class _Header extends StatelessWidget {
  const _Header({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = entry.title.trim();
    final images = DiaryBlocks.imagePaths(entry.content).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        14,
        AppDimens.pagePadding,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? '无标题' : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: title.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                entry.isLined ? Icons.format_align_left : Icons.crop_square,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_dateLabel(entry.diaryDate)} · '
                  '${DiaryTemplateType.label(entry.templateType)}'
                  '${images > 0 ? " · $images 张图片（编辑页查看）" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime d) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${d.month}月${d.day}日 ${weekdays[d.weekday - 1]}';
  }
}

class _MissingView extends StatelessWidget {
  const _MissingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '这篇日记已经不在了',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

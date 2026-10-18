import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/memo_providers.dart';

class MemoEditorPage extends ConsumerStatefulWidget {
  final int? memoId;
  const MemoEditorPage({super.key, this.memoId});

  @override
  ConsumerState<MemoEditorPage> createState() => _MemoEditorPageState();
}

class _MemoEditorPageState extends ConsumerState<MemoEditorPage> {
  final _ctrl = TextEditingController();
  bool _pinned = false;
  bool _dirty = false;
  bool _loaded = false;
  int? _id;

  @override
  void initState() {
    super.initState();
    _id = widget.memoId;
    _load();
  }

  Future<void> _load() async {
    if (_id == null) {
      setState(() => _loaded = true);
      return;
    }
    final all = await ref.read(memoRepositoryProvider).watchAll().first;
    final m = all.where((x) => x.id == _id).firstOrNull;
    if (m != null && mounted) {
      _ctrl.text = m.content;
      _pinned = m.pinned == 1;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    if (!_dirty || _ctrl.text.trim().isEmpty) return;
    _id = await ref.read(memoRepositoryProvider).upsert(
          id: _id,
          content: _ctrl.text.trim(),
          pinned: _pinned,
        );
    _dirty = false;
  }

  @override
  void dispose() {
    _save();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_id == null ? '记一笔' : '编辑备忘'),
        actions: [
          IconButton(
            icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: _pinned ? Colors.amber : null),
            onPressed: () => setState(() {
              _pinned = !_pinned;
              _dirty = true;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              await _save();
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: TextField(
        controller: _ctrl,
        maxLines: null,
        expands: true,
        autofocus: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          hintText: '想到什么写什么...',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        onChanged: (_) => _dirty = true,
      ),
    );
  }
}

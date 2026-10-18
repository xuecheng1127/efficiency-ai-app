import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/birthday_providers.dart';

class BirthdayAddPage extends ConsumerStatefulWidget {
  const BirthdayAddPage({super.key});

  @override
  ConsumerState<BirthdayAddPage> createState() => _BirthdayAddPageState();
}

class _BirthdayAddPageState extends ConsumerState<BirthdayAddPage> {
  final _name = TextEditingController();
  int _month = 1;
  int _day = 1;
  String _calType = 'solar';
  String _group = '其他';
  int _advance = 3;

  final _groups = const ['家人', '朋友', '同事', '其他'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加生日')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '姓名（必填）'),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('生日（月/日）'),
            trailing: DropdownButton<int>(
              value: _month,
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text('$m月')),
              ],
              onChanged: (v) => setState(() => _month = v!),
            ),
          ),
          ListTile(
            title: const Text('日'),
            trailing: DropdownButton<int>(
              value: _day,
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('$d日')),
              ],
              onChanged: (v) => setState(() => _day = v!),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'solar', label: Text('公历')),
              ButtonSegment(value: 'lunar', label: Text('农历')),
            ],
            selected: {_calType},
            onSelectionChanged: (s) => setState(() => _calType = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '分组'),
            value: _group,
            items: [
              for (final g in _groups)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _group = v!),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('提前提醒天数'),
            trailing: DropdownButton<int>(
              value: _advance,
              items: const [1, 3, 7, 14]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d天')))
                  .toList(),
              onChanged: (v) => setState(() => _advance = v!),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              if (_name.text.trim().isEmpty) return;
              await ref.read(birthdayRepositoryProvider).add(
                    name: _name.text,
                    month: _month,
                    day: _day,
                    calendarType: _calType,
                    groupTag: _group,
                    advanceDays: _advance,
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

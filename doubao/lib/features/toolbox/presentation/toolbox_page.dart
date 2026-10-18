import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'birthday_list_page.dart';
import 'calorie_page.dart';
import 'location_reminder_list_page.dart';
import 'memo_list_page.dart';
import 'shopping_list_page.dart';

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扩展工具箱')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppColors.pagePadding),
        children: [
          _PluginTile(
            icon: Icons.sticky_note_2_outlined,
            title: '备忘录',
            subtitle: '极低摩擦的随手记，想到就写',
            available: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemoListPage()),
            ),
          ),
          _PluginTile(
            icon: Icons.cake_outlined,
            title: '朋友生日',
            subtitle: '公历/农历、提前提醒、分组标签',
            available: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BirthdayListPage()),
            ),
          ),
          _PluginTile(
            icon: Icons.local_fire_department_outlined,
            title: '每日热量',
            subtitle: '快速记吃了什么，看今天摄入多少',
            available: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CaloriePage()),
            ),
          ),
          _PluginTile(
            icon: Icons.near_me_outlined,
            title: '途径提醒',
            subtitle: '走到超市自动提醒买菜，经过快递站提醒拿件',
            available: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LocationReminderListPage()),
            ),
          ),
          _PluginTile(
            icon: Icons.shopping_cart_outlined,
            title: '采购清单',
            subtitle: '分类折叠、已购沉底、模板复用',
            available: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShoppingListPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool available;
  final VoidCallback? onTap;

  const _PluginTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.available = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (available ? AppColors.success : AppColors.primary)
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: available ? AppColors.success : AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
          ),
        ),
        trailing: Chip(
          label: Text(available ? '可用' : '即将上线',
              style: TextStyle(fontSize: 11, color: available ? AppColors.success : null)),
          visualDensity: VisualDensity.compact,
          backgroundColor: available ? AppColors.success.withValues(alpha: 0.1) : null,
        ),
        onTap: onTap,
      ),
    );
  }
}

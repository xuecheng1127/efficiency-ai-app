import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';

/// 极简空状态页（需求：每个模块配备空状态页，禁止空白页面）
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标：柔和圆底承载
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            )
                .animate()
                .fadeIn(duration: 300.ms, curve: AppMotion.easeOutCubic)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: subColor.withValues(alpha: 0.7),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              // 高频操作按钮下沉至下半区（需求：单手优化）
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(160, 48),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

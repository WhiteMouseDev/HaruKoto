import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';

class QuizHeader extends StatelessWidget {
  final String title;
  final String? count;
  final VoidCallback onBack;

  const QuizHeader({
    super.key,
    required this.title,
    this.count,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = this.count;
    if (count == null) {
      final foreground = theme.brightness == Brightness.light
          ? AppColors.redesignForeground
          : theme.colorScheme.onSurface;
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 20, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: '뒤로',
              onPressed: onBack,
              style: IconButton.styleFrom(
                foregroundColor: foreground,
                minimumSize: const Size.square(48),
                padding: const EdgeInsets.only(left: 4),
              ),
              icon: const Icon(LucideIcons.arrowLeft, size: 22),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: redesignFontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    letterSpacing: -0.4,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(LucideIcons.arrowLeft, size: 20),
          ),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            count,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

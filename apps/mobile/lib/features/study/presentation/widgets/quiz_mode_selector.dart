import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class QuizModeSelector extends StatelessWidget {
  final String selectedMode;
  final ValueChanged<String> onChanged;

  const QuizModeSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  static const _modes = [
    ('normal', LucideIcons.bookOpen, '4지선다'),
    ('matching', LucideIcons.link2, '매칭'),
    ('cloze', LucideIcons.textCursorInput, '빈칸'),
    ('arrange', LucideIcons.arrowUpDown, '어순'),
    ('typing', LucideIcons.keyboard, '쓰기'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _modes.map((m) {
        final isActive = selectedMode == m.$1;
        return GestureDetector(
          onTap: () => onChanged(m.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: isActive ? 2 : 1,
              ),
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  m.$2,
                  size: 14,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  m.$3,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

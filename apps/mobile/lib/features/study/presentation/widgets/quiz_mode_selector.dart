import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';

class QuizModeSelector extends StatelessWidget {
  final String selectedMode;
  final ValueChanged<String> onChanged;

  /// If provided, only these modes will be shown.
  /// If null, all modes except typing are shown.
  final List<String>? availableModes;

  const QuizModeSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
    this.availableModes,
  });

  static const _allModes = [
    ('normal', LucideIcons.listChecks, '4지선다'),
    ('matching', LucideIcons.shuffle, '매칭'),
    ('cloze', LucideIcons.textCursorInput, '빈칸'),
    ('arrange', LucideIcons.arrowUpDown, '어순'),
    // typing mode removed (task 1-11)
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final activeColor = isLight ? AppColors.purple : theme.colorScheme.primary;
    final activeBg = isLight
        ? AppColors.purpleTrack
        : theme.colorScheme.primary.withValues(alpha: 0.1);

    final modes = availableModes != null
        ? _allModes.where((m) => availableModes!.contains(m.$1)).toList()
        : _allModes;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((m) {
        final isActive = selectedMode == m.$1;
        return GestureDetector(
          onTap: () => onChanged(m.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: isActive ? activeColor : theme.colorScheme.outline,
                width: isActive ? 2 : 1,
              ),
              color: isActive ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  m.$2,
                  size: 14,
                  color: isActive
                      ? activeColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  m.$3,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? activeColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
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

import 'package:flutter/material.dart';

class LearnedWordsSortTabs extends StatelessWidget {
  final List<(String, String)> sortOptions;
  final String activeSort;
  final ValueChanged<String> onSortChanged;

  const LearnedWordsSortTabs({
    super.key,
    required this.sortOptions,
    required this.activeSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: sortOptions.map((s) {
          final isActive = activeSort == s.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSortChanged(s.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    s.$2,
                    style:
                        theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

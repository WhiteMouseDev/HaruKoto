import 'package:flutter/material.dart';

class JlptLevelSelector extends StatelessWidget {
  final List<String> levels;
  final String selected;
  final ValueChanged<String> onChanged;

  const JlptLevelSelector({
    super.key,
    required this.levels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: levels.map((level) {
        final isActive = selected == level;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: level != levels.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    level,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

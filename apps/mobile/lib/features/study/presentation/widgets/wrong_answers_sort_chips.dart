import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

const wrongAnswersSortOptions = [
  ('most-wrong', '많이 틀린 순'),
  ('recent', '최근 순'),
  ('alphabetical', '가나다 순'),
];

class WrongAnswersSortChips extends StatelessWidget {
  final String activeSort;
  final ValueChanged<String> onSortChanged;

  const WrongAnswersSortChips({
    super.key,
    required this.activeSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final activeBg =
        isLight ? AppColors.sakuraTrack : theme.colorScheme.primary;
    final activeFg = isLight ? AppColors.sakura : theme.colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: wrongAnswersSortOptions.map((option) {
          final isActive = activeSort == option.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSortChanged(option.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? activeBg
                      : theme.colorScheme.surfaceContainerHigh,
                  border: Border.all(
                    color: isActive ? activeFg : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.chipRadius),
                ),
                child: Text(
                  option.$2,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? activeFg
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
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

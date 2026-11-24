import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';

const wordbookFilterOptions = [
  ('ALL', '전체'),
  ('QUIZ', '퀴즈'),
  ('CONVERSATION', '회화'),
  ('MANUAL', '직접 추가'),
];

class WordbookFilterChips extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  const WordbookFilterChips({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final selectedSurface =
        light ? AppColors.redesignStrong : colors.primaryContainer;
    final selectedLabel = light ? Colors.white : colors.onPrimaryContainer;
    final unselectedSurface =
        light ? AppColors.redesignControl : colors.surfaceContainerHigh;
    final unselectedLabel =
        light ? AppColors.redesignForeground : colors.onSurfaceVariant;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: AppSizes.pageHorizontalEdge,
      child: Row(
        spacing: 6,
        children: [
          for (final (value, label) in wordbookFilterOptions)
            Semantics(
              selected: activeFilter == value,
              inMutuallyExclusiveGroup: true,
              child: TextButton(
                onPressed: () => onFilterChanged(value),
                style: TextButton.styleFrom(
                  backgroundColor: activeFilter == value
                      ? selectedSurface
                      : unselectedSurface,
                  foregroundColor:
                      activeFilter == value ? selectedLabel : unselectedLabel,
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontFamily: redesignFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Text(label),
              ),
            ),
        ],
      ),
    );
  }
}

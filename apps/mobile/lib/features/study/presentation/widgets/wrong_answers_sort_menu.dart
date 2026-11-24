import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';

const _wrongAnswersSortOptions = [
  ('most-wrong', '많이 틀린 순'),
  ('recent', '최근 순'),
  ('alphabetical', '가나다 순'),
];

class WrongAnswersSortMenu extends StatelessWidget {
  const WrongAnswersSortMenu({
    super.key,
    required this.activeSort,
    required this.onSortChanged,
  });

  final String activeSort;
  final ValueChanged<String> onSortChanged;

  Future<void> _selectSort(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSheetHandle(),
              const SizedBox(height: 16),
              const Text(
                '정렬',
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final (value, label) in _wrongAnswersSortOptions)
                Semantics(
                  selected: value == activeSort,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: redesignFontFamily,
                      ),
                    ),
                    trailing: value == activeSort
                        ? const Icon(
                            LucideIcons.check,
                            color: AppColors.sakura,
                            size: 18,
                          )
                        : null,
                    onTap: () => Navigator.pop(sheetContext, value),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && context.mounted) onSortChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = colors.brightness == Brightness.light
        ? AppColors.redesignMutedForeground
        : colors.onSurfaceVariant;
    final label = _wrongAnswersSortOptions
        .firstWhere((option) => option.$1 == activeSort,
            orElse: () => _wrongAnswersSortOptions.first)
        .$2;

    return TextButton.icon(
      onPressed: () => _selectSort(context),
      iconAlignment: IconAlignment.end,
      icon: const Icon(LucideIcons.chevronDown, size: 14),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(48, kMinInteractiveDimension),
        padding: const EdgeInsetsDirectional.only(start: 8),
        textStyle: const TextStyle(
          fontFamily: redesignFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';

class StudyListSortMenu extends StatelessWidget {
  const StudyListSortMenu({
    super.key,
    required this.options,
    required this.activeSort,
    required this.onSortChanged,
    this.tapTargetSize = MaterialTapTargetSize.padded,
  });

  final List<(String, String)> options;
  final String activeSort;
  final ValueChanged<String> onSortChanged;
  final MaterialTapTargetSize tapTargetSize;

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
              for (final (value, label) in options)
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
        ? AppColors.redesignForeground
        : colors.onSurfaceVariant;
    final label = options
        .firstWhere((option) => option.$1 == activeSort,
            orElse: () => options.first)
        .$2;

    return TextButton.icon(
      onPressed: () => _selectSort(context),
      iconAlignment: IconAlignment.end,
      icon: const Icon(LucideIcons.chevronDown, size: 14),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(48, 36),
        tapTargetSize: tapTargetSize,
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsetsDirectional.only(start: 8),
        textStyle: const TextStyle(
          fontFamily: redesignFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';

Future<int?> showTodayStudyGoalPicker({
  required BuildContext context,
  required int currentGoal,
  required String title,
}) {
  const goals = [5, 10, 15, 20, 30];

  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: AppSizes.sheetShape,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSheetHandle(),
              const SizedBox(height: 16),
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              for (final goal in goals)
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  selected: goal == currentGoal,
                  selectedTileColor:
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                  title: Text('$goal개'),
                  trailing: goal == currentGoal
                      ? Icon(LucideIcons.check,
                          color: theme.colorScheme.primary, size: 20)
                      : null,
                  onTap: () => Navigator.of(context).pop(goal),
                ),
            ],
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'today_study_sheet_handle.dart';

Future<int?> showTodayStudyGoalPicker({
  required BuildContext context,
  required int currentGoal,
  required bool isGoalLoading,
}) {
  const goals = [5, 10, 15, 20, 30];

  return showModalBottomSheet<int>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TodayStudySheetHandle(),
              const SizedBox(height: 16),
              Text(
                '하루 목표 설정',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...goals.map((goal) {
                final isActive = goal == currentGoal;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: isActive,
                  selectedTileColor:
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                  title: Text(
                    '$goal개',
                    style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: isGoalLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : isActive
                          ? Icon(
                              LucideIcons.check,
                              color: theme.colorScheme.primary,
                              size: 20,
                            )
                          : null,
                  enabled: !isGoalLoading,
                  onTap: () {
                    Navigator.pop(ctx, goal);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

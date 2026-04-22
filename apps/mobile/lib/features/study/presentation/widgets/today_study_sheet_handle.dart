import 'package:flutter/material.dart';

class TodayStudySheetHandle extends StatelessWidget {
  const TodayStudySheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

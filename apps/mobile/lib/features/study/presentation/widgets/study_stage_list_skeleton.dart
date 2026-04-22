import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';

/// Skeleton loader for the stage list.
class StudyStageListSkeleton extends StatelessWidget {
  const StudyStageListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: List.generate(
        5,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        ),
      ),
    );
  }
}

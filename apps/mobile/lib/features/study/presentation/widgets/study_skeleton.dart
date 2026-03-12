import 'package:flutter/material.dart';
import '../../../../core/constants/sizes.dart';

class StudySkeleton extends StatelessWidget {
  const StudySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 32,
          width: 128,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius:
                BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 112,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(
                    AppSizes.cardRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';

class LessonResultActions extends StatelessWidget {
  final VoidCallback onDone;
  final VoidCallback onRetry;

  const LessonResultActions({
    super.key,
    required this.onDone,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: onDone,
                icon: const Icon(LucideIcons.bookOpen, size: 18),
                label: const Text('학습으로 돌아가기'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryStrong,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onRetry,
                    child: const Text('다시 풀기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

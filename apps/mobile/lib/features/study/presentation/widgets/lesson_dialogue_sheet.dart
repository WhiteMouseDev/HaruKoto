import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_dialogue_bubble.dart';

void showLessonDialogueSheet(BuildContext context, LessonDetailModel detail) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSizes.md),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSizes.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            '대화 다시 보기',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          ...detail.content.reading.script.map(
            (line) => LessonDialogueBubble(
              line: line,
              showTranslation: true,
            ),
          ),
        ],
      ),
    ),
  );
}

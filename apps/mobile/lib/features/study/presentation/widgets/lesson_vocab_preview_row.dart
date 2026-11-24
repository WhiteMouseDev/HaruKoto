import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/lesson_models.dart';

BoxDecoration lessonPreviewRowDecoration(ThemeData theme) {
  final light = theme.brightness == Brightness.light;
  return BoxDecoration(
    color: light ? AppColors.lightCard : theme.colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color:
          light ? AppColors.redesignOutline : theme.colorScheme.outlineVariant,
    ),
  );
}

class LessonVocabPreviewRow extends StatelessWidget {
  const LessonVocabPreviewRow({super.key, required this.vocab});

  final VocabItemModel vocab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final reading = vocab.reading.trim();
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: redesignFontFamily,
      color: foreground,
    );

    return DecoratedBox(
      decoration: lessonPreviewRowDecoration(theme),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.sm),
              child: Icon(
                Icons.circle,
                size: 6,
                color: light ? AppColors.brandPink : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        vocab.word,
                        style: style?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (reading.isNotEmpty && reading != vocab.word)
                        Text(
                          reading,
                          style: style?.copyWith(
                            fontSize: 12,
                            color: light
                                ? AppColors.redesignMutedForeground
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(vocab.meaningKo, style: style),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

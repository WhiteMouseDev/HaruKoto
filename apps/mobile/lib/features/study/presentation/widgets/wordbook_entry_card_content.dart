import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/wordbook_entry_model.dart';

class WordbookEntryCardContent extends StatelessWidget {
  const WordbookEntryCardContent({
    super.key,
    required this.entry,
    required this.expanded,
  });

  final WordbookEntryModel entry;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final secondary =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    final (sourceLabel, sourceColor) = switch (entry.source) {
      'QUIZ' => ('퀴즈', AppColors.redesignGrammar),
      'CONVERSATION' => ('회화', AppColors.redesignSentence),
      _ => ('직접 추가', AppColors.redesignVocabulary),
    };

    return Row(
      children: [
        Semantics(
          label: sourceLabel,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: sourceColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const SizedBox.square(dimension: 12),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    entry.word,
                    style: HaruTypography.krTitle3.copyWith(
                      color: foreground,
                      fontFamily: redesignJapaneseFontFamily,
                      fontSize: 16,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (entry.reading.trim().isNotEmpty)
                    Text(entry.reading,
                        style:
                            HaruTypography.jpBody3.copyWith(color: secondary)),
                ],
              ),
              const SizedBox(height: 2),
              Text(entry.meaningKo,
                  style: HaruTypography.krBody3.copyWith(color: secondary)),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Icon(expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            size: 16, color: secondary),
      ],
    );
  }
}

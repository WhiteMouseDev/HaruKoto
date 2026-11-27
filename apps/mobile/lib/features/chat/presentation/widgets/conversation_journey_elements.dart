import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../data/models/conversation_journey_episode.dart';
import '../../data/models/scenario_model.dart';
import '../scenario_difficulty.dart';

class ConversationJourneyProgressSummary extends StatelessWidget {
  const ConversationJourneyProgressSummary({
    super.key,
    required this.practicedCount,
    required this.totalCount,
    this.filled = false,
  });

  final int practicedCount;
  final int totalCount;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final muted = light ? const Color(0xFF505050) : colors.onSurfaceVariant;
    final outline = light ? AppColors.redesignOutline : colors.outlineVariant;
    final surface =
        light ? AppColors.redesignSurface : colors.surfaceContainerHigh;

    return Container(
      constraints: BoxConstraints(minHeight: filled ? 32 : 34),
      decoration: BoxDecoration(
        color: filled ? surface : null,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: filled ? null : Border.all(color: outline),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.gap, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '연습 현황',
              style: HaruTypography.krBody3.copyWith(color: muted),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              '$practicedCount / $totalCount장면',
              textAlign: TextAlign.end,
              style: HaruTypography.krBody3.copyWith(
                color: foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationJourneyEpisodeNumber extends StatelessWidget {
  const ConversationJourneyEpisodeNumber({
    super.key,
    required this.number,
    required this.isPracticed,
  });

  final int number;
  final bool isPracticed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final ring = switch ((light, isPracticed)) {
      (true, true) => AppColors.redesignVocabulary,
      (true, false) => AppColors.redesignOutline,
      (false, true) => AppColors.sakuraContainer,
      (false, false) => colors.outlineVariant,
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.all(AppSizes.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 4),
      ),
      child: Text(
        number.toString().padLeft(2, '0'),
        style: HaruTypography.krTitle3.copyWith(
          fontSize: 16,
          letterSpacing: -0.4,
          color: light ? Colors.black : colors.onSurface,
        ),
      ),
    );
  }
}

class ConversationJourneyEpisodeMeta extends StatelessWidget {
  const ConversationJourneyEpisodeMeta({
    super.key,
    required this.episode,
    required this.scenario,
    required this.isPracticed,
    this.showRecommendation = false,
    this.alignment = WrapAlignment.start,
  });

  final ConversationJourneyEpisode episode;
  final ScenarioModel? scenario;
  final bool isPracticed;
  final bool showRecommendation;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final muted = light ? const Color(0xFF505050) : colors.onSurfaceVariant;
    final accent = light ? AppColors.sakuraOn : AppColors.sakuraContainer;
    final labelStyle = HaruTypography.krBody3.copyWith(color: muted);
    final difficulty = scenarioDifficultyLabel(scenario?.difficulty ?? '');
    final labels = [
      if (difficulty.isNotEmpty) (difficulty, labelStyle),
      (isPracticed ? '연습함' : '연습 전', labelStyle),
      if (showRecommendation) ('다음 추천', labelStyle.copyWith(color: accent)),
    ];
    final estimatedMinutes =
        episode.estimatedMinutesWithFallback(scenario?.estimatedMinutes);
    final separator = ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(right: AppSizes.xs),
        child: Text('·', style: labelStyle),
      ),
    );

    return Wrap(
      spacing: AppSizes.xs,
      runSpacing: 2,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (index, (label, style)) in labels.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0) separator,
              Flexible(child: Text(label, style: style)),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            separator,
            ExcludeSemantics(
              child: Image.asset(
                'assets/icons/figma-study-recommendation-clock.png',
                width: 14,
                height: 14,
                color: light ? null : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSizes.xs),
            Flexible(
              child: Text('약 $estimatedMinutes분', style: labelStyle),
            ),
          ],
        ),
      ],
    );
  }
}

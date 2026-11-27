import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../data/models/conversation_journey_episode.dart';
import '../../data/models/scenario_model.dart';
import 'conversation_journey_elements.dart';

class ConversationJourneySheet extends StatelessWidget {
  const ConversationJourneySheet({
    super.key,
    required this.episodes,
    required this.scenarios,
    required this.practicedIds,
    required this.recommendedId,
  });

  final List<ConversationJourneyEpisode> episodes;
  final Map<String, ScenarioModel> scenarios;
  final Set<String> practicedIds;
  final String recommendedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final practicedCount = episodes
        .where((episode) => practicedIds.contains(episode.scenarioId))
        .length;
    final headingStyle = HaruTypography.krTitle2.copyWith(color: foreground);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pageHorizontal,
          AppSizes.md,
          AppSizes.pageHorizontal,
          AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(tokyoFirstDayTitle, style: headingStyle),
            ),
            const SizedBox(height: AppSizes.lg),
            Text('추천 순서대로,\n또는 필요한 장면부터 골라요.', style: headingStyle),
            const SizedBox(height: AppSizes.sm),
            ConversationJourneyProgressSummary(
              practicedCount: practicedCount,
              totalCount: episodes.length,
            ),
            const SizedBox(height: 40),
            for (final episode in episodes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: _JourneyEpisodeRow(
                  episode: episode,
                  scenario: scenarios[episode.scenarioId],
                  isPracticed: practicedIds.contains(episode.scenarioId),
                  isRecommended: episode.scenarioId == recommendedId,
                  onSelect: () => Navigator.of(context).pop(episode),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JourneyEpisodeRow extends StatelessWidget {
  const _JourneyEpisodeRow({
    required this.episode,
    required this.scenario,
    required this.isPracticed,
    required this.isRecommended,
    required this.onSelect,
  });

  final ConversationJourneyEpisode episode;
  final ScenarioModel? scenario;
  final bool isPracticed;
  final bool isRecommended;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final muted = light ? const Color(0xFF505050) : colors.onSurfaceVariant;
    final outline = light ? AppColors.redesignOutline : colors.outlineVariant;
    final description = episode.descriptionWithFallback(scenario?.description);
    final titleStyle = HaruTypography.krTitle3.copyWith(
      color: foreground,
      fontSize: 15,
      height: 1.5,
      letterSpacing: -0.375,
    );
    final descriptionStyle = HaruTypography.krBody3.copyWith(
      color: muted,
      fontSize: 14,
      letterSpacing: -0.35,
    );

    return OutlinedButton(
      onPressed: onSelect,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: light ? Colors.white : colors.surface,
        side: BorderSide(color: outline),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSizes.gap)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.gap,
        ),
        minimumSize: const Size(0, AppSizes.buttonHeight),
        visualDensity: VisualDensity.standard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: ConversationJourneyEpisodeNumber(
              number: episode.number,
              isPracticed: isPracticed,
            ),
          ),
          const SizedBox(width: AppSizes.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(episode.title, style: titleStyle),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(description, style: descriptionStyle),
                ],
                const SizedBox(height: AppSizes.gap),
                Row(
                  children: [
                    Expanded(
                      child: ConversationJourneyEpisodeMeta(
                        episode: episode,
                        scenario: scenario,
                        isPracticed: isPracticed,
                        showRecommendation: isRecommended && !isPracticed,
                      ),
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Icon(
                      LucideIcons.chevronRight,
                      size: AppSizes.iconSm,
                      color: muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

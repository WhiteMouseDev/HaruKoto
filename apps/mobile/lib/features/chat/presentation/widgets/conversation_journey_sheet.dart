import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/conversation_journey_episode.dart';

class ConversationJourneySheet extends StatelessWidget {
  const ConversationJourneySheet({
    super.key,
    required this.episodes,
    required this.practicedIds,
    required this.recommendedId,
  });

  final List<ConversationJourneyEpisode> episodes;
  final Set<String> practicedIds;
  final String recommendedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? AppColors.sakuraContainer : AppColors.sakuraOn;
    final practicedCount =
        episodes.where((item) => practicedIds.contains(item.scenarioId)).length;
    final progress = '${episodes.length}장면 중 $practicedCount장면 연습';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '여행 · 말하기 여정',
              style: theme.textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Semantics(
              header: true,
              child: Text(
                '도쿄 첫날',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              '추천 순서대로, 또는 필요한 장면부터 골라요.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              progress,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (episodes.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: practicedCount / episodes.length,
                  minHeight: AppSizes.progressHeight,
                  borderRadius: BorderRadius.circular(AppSizes.progressRadius),
                  color: accent,
                  backgroundColor: colors.surfaceContainerHighest,
                ),
              ),
            ],
            const SizedBox(height: AppSizes.md),
            for (final episode in episodes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: _JourneyEpisodeRow(
                  episode: episode,
                  isPracticed: practicedIds.contains(episode.scenarioId),
                  isRecommended: episode.scenarioId == recommendedId,
                  accent: accent,
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
    required this.isPracticed,
    required this.isRecommended,
    required this.accent,
    required this.onSelect,
  });

  final ConversationJourneyEpisode episode;
  final bool isPracticed;
  final bool isRecommended;
  final Color accent;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textColor =
        isRecommended && !isPracticed ? accent : colors.onSurfaceVariant;
    final status = isPracticed
        ? '연습 기록 있음'
        : isRecommended
            ? '다음 추천'
            : '바로 시작 가능';
    final background = isRecommended && !isPracticed
        ? Color.alphaBlend(accent.withValues(alpha: 0.10), colors.surface)
        : colors.surfaceContainerLow;
    final borderRadius = BorderRadius.circular(AppSizes.radiusMd);

    return Semantics(
      button: true,
      child: Material(
        color: background,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onSelect,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.gap),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.sm),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: Text(
                        episode.number.toString().padLeft(2, '0'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          '$status · 약 ${episode.estimatedMinutes}분',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: textColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Icon(LucideIcons.chevronRight,
                      size: AppSizes.iconSm, color: textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

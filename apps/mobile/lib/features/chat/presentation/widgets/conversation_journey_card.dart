import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/conversation_journey_episode.dart';
import 'conversation_journey_scene.dart';

class ConversationJourneyCard extends StatelessWidget {
  const ConversationJourneyCard({
    super.key,
    required this.episode,
    required this.practicedCount,
    required this.totalCount,
    required this.allPracticed,
    required this.onPrepare,
    required this.onViewAll,
  });

  final ConversationJourneyEpisode episode;
  final int practicedCount;
  final int totalCount;
  final bool allPracticed;
  final VoidCallback onPrepare;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? AppColors.sakuraContainer : AppColors.sakuraOn;
    final episodeNumber = episode.number.toString().padLeft(2, '0');
    final recommendation = switch ((allPracticed, practicedCount)) {
      (true, _) => '다시 말하기',
      (false, 0) => '오늘의 추천',
      _ => '이어서 말하기',
    };

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ConversationJourneyScene(episodeNumber: episode.number),
              Padding(
                padding: const EdgeInsets.all(AppSizes.gap),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Padding(
                    padding: AppSizes.chipPadding,
                    child: Text(
                      '도쿄 첫날 · $episodeNumber',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, AppSizes.gap, AppSizes.md, AppSizes.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSizes.md,
                  runSpacing: AppSizes.xs,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      recommendation,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$totalCount장면 중 $practicedCount장면 연습',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Semantics(
                  header: true,
                  child: Text(
                    episode.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '${episode.place} · 약 ${episode.estimatedMinutes}분',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                if (episode.goals.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text(episode.goals.first, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: AppSizes.gap),
                FilledButton.icon(
                  onPressed: onPrepare,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: dark ? AppColors.sakuraOn : Colors.white,
                  ),
                  icon: const Icon(LucideIcons.mic, size: AppSizes.iconMd),
                  label: const Text('미션 준비'),
                ),
                Center(
                  child: TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(0, AppSizes.buttonHeight),
                    ),
                    child: const Text('여정 전체 보기'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/haru_button_styles.dart';
import '../../data/models/conversation_journey_episode.dart';
import '../../data/models/scenario_model.dart';
import 'conversation_journey_elements.dart';
import 'conversation_journey_scene.dart';

class ConversationJourneyCard extends StatelessWidget {
  const ConversationJourneyCard({
    super.key,
    required this.episode,
    required this.scenario,
    required this.practicedCount,
    required this.totalCount,
    required this.isRecommendedPracticed,
    required this.onPrepare,
    required this.onViewAll,
  });

  final ConversationJourneyEpisode episode;
  final ScenarioModel scenario;
  final int practicedCount;
  final int totalCount;
  final bool isRecommendedPracticed;
  final VoidCallback onPrepare;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final muted = light ? const Color(0xFF505050) : colors.onSurfaceVariant;
    final outline = light ? AppColors.redesignOutline : colors.outlineVariant;
    final accent =
        light ? AppColors.redesignVocabulary : AppColors.sakuraContainer;
    final recommendation = switch (practicedCount) {
      0 => '첫 말하기 연습',
      _ when practicedCount == totalCount => '다시 말하기',
      _ => '이어서 말하기',
    };
    final description = episode.descriptionWithFallback(scenario.description);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: accent,
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm, vertical: 2),
              child: Text(
                recommendation,
                textAlign: TextAlign.start,
                style: HaruTypography.krPillTab.copyWith(
                  fontSize: 12,
                  letterSpacing: -0.3,
                  color: light ? Colors.white : AppColors.sakuraOn,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Semantics(
          header: true,
          child: Text(
            tokyoFirstDayTitle,
            textAlign: TextAlign.start,
            style: HaruTypography.krTitle2.copyWith(color: foreground),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        ConversationJourneyProgressSummary(
          practicedCount: practicedCount,
          totalCount: totalCount,
          filled: true,
        ),
        const SizedBox(height: AppSizes.gap),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.gap),
          child: ConversationJourneyScene(
            episodeNumber: episode.number,
            height: 120,
          ),
        ),
        const SizedBox(height: 40),
        Semantics(
          header: true,
          child: Text(
            '회화 연습',
            style: HaruTypography.krTitle3.copyWith(
              fontSize: 16,
              letterSpacing: -0.4,
              color: foreground,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gap),
        AppCard.compactSurface(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.md,
            AppSizes.md,
            AppSizes.md,
            AppSizes.md - HaruButtonStyles.compactHitInset,
          ),
          darkSurface: colors.surfaceContainerHigh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConversationJourneyEpisodeNumber(
                    number: episode.number,
                    isPracticed: isRecommendedPracticed,
                  ),
                  const SizedBox(width: AppSizes.gap),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ConversationJourneyEpisodeMeta(
                        episode: episode,
                        scenario: scenario,
                        isPracticed: isRecommendedPracticed,
                        alignment: WrapAlignment.end,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              Semantics(
                header: true,
                child: Text(
                  episode.title,
                  style: HaruTypography.krTitle3.copyWith(color: foreground),
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                description,
                style: HaruTypography.krBody3.copyWith(
                  fontSize: 14,
                  letterSpacing: -0.35,
                  color: muted,
                ),
              ),
              const SizedBox(
                  height: AppSizes.md - HaruButtonStyles.compactHitInset),
              FilledButton(
                onPressed: onPrepare,
                style: HaruButtonStyles.primary(context),
                child: const Text('연습 시작'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        OutlinedButton(
          onPressed: onViewAll,
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground,
            side: BorderSide(color: outline),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
            textStyle: HaruTypography.krPillTab,
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 7),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Flexible(
                  child: Text('장면 전체 보기', textAlign: TextAlign.center)),
              const SizedBox(width: AppSizes.sm),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: light ? AppColors.redesignStrong : foreground,
              ),
            ],
          ),
        ),
        const SizedBox(height: 34),
      ],
    );
  }
}

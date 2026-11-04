import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/conversation_journey_episode.dart';
import '../../data/models/scenario_model.dart';
import '../chat_entry_mode.dart';
import 'conversation_journey_scene.dart';

/// Returns the chosen input mode; the parent starts the conversation afterward.
class ScenarioPreparationSheet extends StatelessWidget {
  const ScenarioPreparationSheet({
    super.key,
    required this.scenario,
    this.journeyEpisode,
  });

  final ScenarioModel scenario;
  final ConversationJourneyEpisode? journeyEpisode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final episode = journeyEpisode;
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? AppColors.sakuraContainer : AppColors.sakuraOn;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (episode != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                child: ConversationJourneyScene(
                  episodeNumber: episode.number,
                  height: 84,
                ),
              ),
              const SizedBox(height: AppSizes.gap),
              Text(
                '도쿄 첫날 · ${episode.number.toString().padLeft(2, '0')}'
                ' · 약 ${episode.estimatedMinutes}분',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Semantics(
                header: true,
                child: Text(episode.title, style: theme.textTheme.titleLarge),
              ),
            ] else ...[
              Text(scenario.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSizes.sm),
              Text('예상 ${scenario.estimatedMinutes}분 · 상황에 맞게 이야기해 보세요'),
            ],
            if (scenario.situation.isNotEmpty) ...[
              SizedBox(height: episode == null ? AppSizes.md : AppSizes.sm),
              Text(scenario.situation),
            ],
            if (scenario.yourRole.isNotEmpty || scenario.aiRole.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Text('나의 역할: ${scenario.yourRole}\n상대 역할: ${scenario.aiRole}'),
            ],
            if (episode != null) ...[
              const SizedBox(height: AppSizes.md),
              _JourneyGoals(goals: episode.goals),
            ] else if (scenario.keyExpressions.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              Text('시작 전에 볼 표현', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSizes.sm),
              ...scenario.keyExpressions.take(3).map(
                    (expression) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      child: Text(expression),
                    ),
                  ),
            ],
            const SizedBox(height: AppSizes.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(ChatEntryMode.voice),
                style: episode == null
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor:
                            dark ? AppColors.sakuraOn : Colors.white,
                      ),
                icon: const Icon(LucideIcons.mic),
                label: const Text('말하기로 연습'),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                ),
                onPressed: () => Navigator.of(context).pop(ChatEntryMode.text),
                icon: const Icon(LucideIcons.messageSquare,
                    size: AppSizes.iconSm),
                label: const Text('글로 연습'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyGoals extends StatelessWidget {
  const _JourneyGoals({required this.goals});

  final List<String> goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('오늘 해볼 두 가지', style: theme.textTheme.titleSmall),
            for (final (index, goal) in goals.indexed)
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.sm),
                child: Text('${index + 1}. $goal'),
              ),
          ],
        ),
      ),
    );
  }
}

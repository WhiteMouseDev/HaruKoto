import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../providers/kana_provider.dart';
import 'widgets/kana_stage_card.dart';

class KanaTypePage extends ConsumerWidget {
  final String type; // 'hiragana' or 'katakana'

  const KanaTypePage({super.key, required this.type});

  String get kanaType => type == 'katakana' ? 'KATAKANA' : 'HIRAGANA';
  String get label => kanaType == 'HIRAGANA' ? '히라가나' : '가타카나';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stagesAsync = ref.watch(kanaStagesProvider(kanaType));
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: stagesAsync.when(
          loading: () => const AppSkeleton(
            itemCount: 5,
            itemHeights: [28, 24, 96, 96, 96],
          ),
          error: (error, _) => AppErrorRetry(
            onRetry: () => ref.invalidate(kanaStagesProvider(kanaType)),
          ),
          data: (stages) {
            final completedCount =
                stages.where((s) => s.isCompleted).length;
            final totalCount = stages.length;
            final progressPct = totalCount > 0
                ? (completedCount / totalCount * 100).round()
                : 0;
            final hasCompleted = stages.any((s) => s.isCompleted);
            final allCompleted =
                stages.isNotEmpty && stages.every((s) => s.isCompleted);

            return RefreshIndicator(
              color: theme.colorScheme.primary,
              onRefresh: () async {
                ref.invalidate(kanaStagesProvider(kanaType));
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: AppSizes.md,
                ),
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.arrowLeft, size: 20),
                        onPressed: () => context.pop(),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        '$label 학습',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Progress bar
                  _KanaProgressBar(
                    label: label,
                    completed: completedCount,
                    total: totalCount,
                    pct: progressPct,
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Stage cards
                  ...stages.map((stage) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSizes.sm + 4),
                      child: KanaStageCard(
                        stageNumber: stage.stageNumber,
                        title: stage.title,
                        description: stage.description,
                        characters: stage.characters,
                        isUnlocked: stage.isUnlocked,
                        isCompleted: stage.isCompleted,
                        quizScore: stage.quizScore,
                        onTap: stage.isUnlocked
                            ? () => context.push(
                                '/study/kana/$type/stage/${stage.stageNumber}')
                            : null,
                      ),
                    );
                  }),

                  // Quiz CTA
                  if (hasCompleted) ...[
                    const SizedBox(height: AppSizes.sm),
                    OutlinedButton(
                      onPressed: () => context.push(
                          '/study/kana/$type/quiz?mode=recognition'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.buttonRadius),
                        ),
                      ),
                      child: Text('$label 퀴즈 도전하기'),
                    ),
                    const SizedBox(height: AppSizes.md),

                    // Quiz mode options
                    Text(
                      '퀴즈 모드',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _quizModeButton(
                            context,
                            '가나 인식',
                            () => context.push(
                                '/study/kana/$type/quiz?mode=recognition'),
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: _quizModeButton(
                            context,
                            '발음 매칭',
                            () => context.push(
                                '/study/kana/$type/quiz?mode=sound_matching'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.sm),
                    _quizModeButton(
                      context,
                      '히라↔가타 매칭',
                      () => context.push(
                          '/study/kana/$type/quiz?mode=kana_matching'),
                    ),
                  ],

                  // Master Quiz
                  if (allCompleted) ...[
                    const SizedBox(height: AppSizes.lg),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.cardRadius),
                        side: BorderSide(color: theme.colorScheme.primary),
                      ),
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.trophy,
                                  size: 24,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$label 마스터 퀴즈',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '전체 출제 · 90% 이상 통과',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => context.push(
                                  '/study/kana/$type/quiz?mode=recognition&master=true'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.buttonRadius),
                                ),
                              ),
                              child: const Text('도전하기'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSizes.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _quizModeButton(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _KanaProgressBar extends StatelessWidget {
  final String label;
  final int completed;
  final int total;
  final int pct;

  const _KanaProgressBar({
    required this.label,
    required this.completed,
    required this.total,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label 학습 진행',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              '$completed/$total',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? completed / total : 0,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$pct%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}


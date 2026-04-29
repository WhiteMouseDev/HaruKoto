import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/smart_preview_model.dart';
import '../../providers/study_provider.dart';
import '../quiz_launch.dart';

class SmartLearningCard extends ConsumerWidget {
  final String jlptLevel;

  const SmartLearningCard({super.key, required this.jlptLevel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(
      smartPreviewProvider((category: 'VOCABULARY', jlptLevel: jlptLevel)),
    );

    return previewAsync.when(
      loading: () => _buildSkeleton(context),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) => _buildCard(context, ref, data),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    SmartPreviewModel data,
  ) {
    final theme = Theme.of(context);
    final dist = data.sessionDistribution;
    final progress = data.overallProgress;
    final hasContent = dist.total > 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.brain,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '스마트 학습',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$jlptLevel · ${progress.studied}/${progress.total}단어',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Circular progress
                _CircularProgress(
                  completed: data.todayCompleted,
                  goal: data.dailyGoal,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Distribution summary
            Row(
              children: [
                _PoolChip(
                  label: '새 단어',
                  count: dist.newCount,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                _PoolChip(
                  label: '복습',
                  count: dist.review,
                  color: AppColors.success(theme.brightness),
                ),
                const SizedBox(width: 8),
                _PoolChip(
                  label: '재도전',
                  count: dist.retry,
                  color: theme.colorScheme.error,
                ),
              ],
            ),

            // Review debt badge
            if (data.poolSize.reviewDue > 30) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning(theme.brightness)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.alertTriangle,
                      size: 14,
                      color: AppColors.warning(theme.brightness),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '복습 ${data.poolSize.reviewDue}개 밀려있어요',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.warning(theme.brightness),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: hasContent
                    ? () => _startSmartQuiz(context, ref, dist.total)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.play, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      hasContent ? '학습 시작 (${dist.total}문제)' : '학습할 단어가 없습니다',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startSmartQuiz(BuildContext context, WidgetRef ref, int count) {
    openQuizPageForSession(
      context,
      quizType: 'VOCABULARY',
      jlptLevel: jlptLevel,
      count: count,
      mode: 'smart',
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularProgress extends StatelessWidget {
  final int completed;
  final int goal;
  final ThemeData theme;

  const _CircularProgress({
    required this.completed,
    required this.goal,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (completed / goal).clamp(0.0, 1.0) : 0.0;
    final trackColor = theme.brightness == Brightness.light
        ? AppColors.surfaceMuted
        : theme.colorScheme.surfaceContainerHigh;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
          Text(
            '$completed',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoolChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _PoolChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

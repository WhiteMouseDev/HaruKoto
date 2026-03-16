import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/smart_preview_model.dart';
import '../../providers/study_provider.dart';
import '../quiz_page.dart';

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
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
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
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                  color: const Color(0xFF10B981),
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
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.alertTriangle,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '복습 ${data.poolSize.reviewDue}개 밀려있어요',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF92400E),
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
                    borderRadius: BorderRadius.circular(12),
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
    Navigator.of(context, rootNavigator: true).push(
      quizRoute(QuizPage(
        quizType: 'VOCABULARY',
        jlptLevel: jlptLevel,
        count: count,
        mode: 'smart',
      )),
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
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

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
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
        borderRadius: BorderRadius.circular(8),
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

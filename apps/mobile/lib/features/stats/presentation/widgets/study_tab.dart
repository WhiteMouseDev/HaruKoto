import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/level_progress_model.dart';
import '../../data/models/stats_history_model.dart';

class StudyTab extends StatelessWidget {
  final LevelProgressData levelProgress;
  final List<StatsHistoryRecord> historyRecords;

  const StudyTab({
    super.key,
    required this.levelProgress,
    required this.historyRecords,
  });

  String _formatTime(int seconds) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins분';
    final hours = mins ~/ 60;
    final remainder = mins % 60;
    return remainder > 0 ? '$hours시간 $remainder분' : '$hours시간';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    // Cumulative stats
    var totalQuizzes = 0;
    var totalCorrect = 0;
    var totalAnswers = 0;
    var totalConversations = 0;
    var totalStudySeconds = 0;

    for (final r in historyRecords) {
      totalQuizzes += r.quizzesCompleted;
      totalCorrect += r.correctAnswers;
      totalAnswers += r.totalAnswers;
      totalConversations += r.conversationCount;
      totalStudySeconds += r.studyTimeSeconds;
    }

    final accuracy =
        totalAnswers > 0 ? (totalCorrect / totalAnswers * 100).round() : 0;

    final vocab = levelProgress.vocabulary;
    final grammar = levelProgress.grammar;
    final vocabPct =
        vocab.total > 0 ? (vocab.mastered / vocab.total * 100).round() : 0;
    final grammarPct =
        grammar.total > 0 ? (grammar.mastered / grammar.total * 100).round() : 0;

    return Column(
      children: [
        // Cumulative Summary
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '누적 학습 요약',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryItem(
                      icon: LucideIcons.target,
                      value: '$totalQuizzes',
                      label: '퀴즈 완료',
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    _SummaryItem(
                      icon: LucideIcons.zap,
                      value: '$accuracy%',
                      label: '정답률',
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    _SummaryItem(
                      icon: LucideIcons.clock,
                      value: _formatTime(totalStudySeconds),
                      label: '총 학습',
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Vocabulary
        _ProgressCard(
          icon: LucideIcons.bookOpen,
          iconColor: theme.colorScheme.primary,
          title: '단어',
          percentage: vocabPct,
          mastered: vocab.mastered,
          inProgress: vocab.inProgress,
          total: vocab.total,
          primaryColor: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),

        // Grammar
        _ProgressCard(
          icon: LucideIcons.bookMarked,
          iconColor: AppColors.success(brightness),
          title: '문법',
          percentage: grammarPct,
          mastered: grammar.mastered,
          inProgress: grammar.inProgress,
          total: grammar.total,
          primaryColor: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),

        // Conversation
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.messageCircle,
                      size: 20,
                      color: AppColors.hkBlue(theme.brightness),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '회화',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalConversations회',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '총 대화 수',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTime(totalStudySeconds),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '대화 시간',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int percentage;
  final int mastered;
  final int inProgress;
  final int total;
  final Color primaryColor;

  const _ProgressCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.percentage,
    required this.mastered,
    required this.inProgress,
    required this.total,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlearned = (total - mastered - inProgress).clamp(0, total);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$percentage% 마스터',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 6,
                backgroundColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(primaryColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LegendDot(
                  color: primaryColor,
                  label: '마스터',
                  count: mastered,
                ),
                _LegendDot(
                  color: primaryColor.withValues(alpha: 0.4),
                  label: '학습 중',
                  count: inProgress,
                ),
                _LegendDot(
                  color: theme.colorScheme.surfaceContainerHigh,
                  label: '미학습',
                  count: unlearned,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $count개',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

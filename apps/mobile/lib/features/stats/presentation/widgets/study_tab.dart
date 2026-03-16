import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/by_category_model.dart';
import '../../data/models/level_progress_model.dart';
import '../../data/models/stats_history_model.dart';
import '../../data/models/volume_chart_model.dart';
import '../../providers/stats_provider.dart';

class StudyTab extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    // Cumulative stats from history
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

    // API data
    final volumeAsync = ref.watch(volumeChartProvider(7));
    final categoryAsync = ref.watch(byCategoryProvider);

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

        // Category Comparison (from by-category API)
        categoryAsync.when(
          data: (category) => _CategoryComparisonCard(category: category),
          loading: () => const _CategoryComparisonCard(category: null),
          error: (_, __) => const _CategoryComparisonCard(category: null),
        ),
        const SizedBox(height: 12),

        // Volume Chart (from volume-chart API)
        volumeAsync.when(
          data: (response) => _VolumeChartCard(entries: response.data),
          loading: () => const _VolumeChartCard(entries: []),
          error: (_, __) => const _VolumeChartCard(entries: []),
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
                      color: AppColors.hkBlue(brightness),
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

/// Category comparison card showing vocabulary vs grammar vs sentences
class _CategoryComparisonCard extends StatelessWidget {
  final ByCategoryResponse? category;

  const _CategoryComparisonCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final vocabTotal = category?.vocabulary.total ?? 0;
    final grammarTotal = category?.grammar.total ?? 0;
    final sentencesTotal = category?.sentences.total ?? 0;
    final grandTotal = vocabTotal + grammarTotal + sentencesTotal;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '카테고리별 학습량',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (category == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '데이터를 불러오는 중...',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            else ...[
              // Stacked bar
              if (grandTotal > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        if (vocabTotal > 0)
                          Expanded(
                            flex: vocabTotal,
                            child: Container(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        if (grammarTotal > 0)
                          Expanded(
                            flex: grammarTotal,
                            child: Container(
                              color: AppColors.success(brightness),
                            ),
                          ),
                        if (sentencesTotal > 0)
                          Expanded(
                            flex: sentencesTotal,
                            child: Container(
                              color: AppColors.hkBlue(brightness),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Legend items
              _CategoryRow(
                color: theme.colorScheme.primary,
                label: '단어',
                count: vocabTotal,
                total: grandTotal,
              ),
              const SizedBox(height: 8),
              _CategoryRow(
                color: AppColors.success(brightness),
                label: '문법',
                count: grammarTotal,
                total: grandTotal,
              ),
              const SizedBox(height: 8),
              _CategoryRow(
                color: AppColors.hkBlue(brightness),
                label: '문장',
                count: sentencesTotal,
                total: grandTotal,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;

  const _CategoryRow({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total > 0 ? (count / total * 100).round() : 0;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          '$count개',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Volume chart showing daily study volume breakdown for last 7 days
class _VolumeChartCard extends StatelessWidget {
  final List<VolumeChartEntry> entries;

  const _VolumeChartCard({required this.entries});

  static const double _chartHeight = 120;

  String _formatDateLabel(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length >= 3) {
      return '${int.parse(parts[1])}/${int.parse(parts[2])}';
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '일별 학습량 (최근 7일)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    '데이터를 불러오는 중...',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: _chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: entries.map((entry) {
                    final total = entry.wordsStudied +
                        entry.grammarStudied +
                        entry.sentencesStudied;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _StackedBar(
                          wordsStudied: entry.wordsStudied,
                          grammarStudied: entry.grammarStudied,
                          sentencesStudied: entry.sentencesStudied,
                          total: total,
                          maxTotal: _maxTotal,
                          chartHeight: _chartHeight,
                          primaryColor: theme.colorScheme.primary,
                          successColor: AppColors.success(brightness),
                          blueColor: AppColors.hkBlue(brightness),
                          emptyColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: entries.map((entry) {
                  return Expanded(
                    child: Text(
                      _formatDateLabel(entry.date),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ChartLegendDot(
                    color: theme.colorScheme.primary,
                    label: '단어',
                  ),
                  const SizedBox(width: 16),
                  _ChartLegendDot(
                    color: AppColors.success(brightness),
                    label: '문법',
                  ),
                  const SizedBox(width: 16),
                  _ChartLegendDot(
                    color: AppColors.hkBlue(brightness),
                    label: '문장',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  int get _maxTotal {
    if (entries.isEmpty) return 1;
    return entries.fold<int>(1, (m, e) {
      final t = e.wordsStudied + e.grammarStudied + e.sentencesStudied;
      return t > m ? t : m;
    });
  }
}

class _StackedBar extends StatelessWidget {
  final int wordsStudied;
  final int grammarStudied;
  final int sentencesStudied;
  final int total;
  final int maxTotal;
  final double chartHeight;
  final Color primaryColor;
  final Color successColor;
  final Color blueColor;
  final Color emptyColor;

  const _StackedBar({
    required this.wordsStudied,
    required this.grammarStudied,
    required this.sentencesStudied,
    required this.total,
    required this.maxTotal,
    required this.chartHeight,
    required this.primaryColor,
    required this.successColor,
    required this.blueColor,
    required this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: emptyColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ],
      );
    }

    final maxBarPx = chartHeight - 20;
    final ratio = total / maxTotal;
    final barHeight = (math.sqrt(ratio) * maxBarPx).clamp(16.0, maxBarPx);

    final wordsPx = total > 0 ? (wordsStudied / total * barHeight) : 0.0;
    final grammarPx = total > 0 ? (grammarStudied / total * barHeight) : 0.0;
    final sentencesPx = barHeight - wordsPx - grammarPx;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            '$total',
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          child: SizedBox(
            height: barHeight,
            child: Column(
              children: [
                if (sentencesPx > 0)
                  Container(height: sentencesPx, color: blueColor),
                if (grammarPx > 0)
                  Container(height: grammarPx, color: successColor),
                if (wordsPx > 0)
                  Container(height: wordsPx, color: primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

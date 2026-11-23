import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_error_retry.dart';
import '../../data/models/study_overview_model.dart';
import '../../providers/stats_provider.dart';
import 'stats_bar_chart.dart';

class StudyTab extends ConsumerWidget {
  const StudyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(studyOverviewProvider).when(
          data: (overview) => _StudyOverviewContent(overview: overview),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: '학습별 통계를 불러오는 중',
              ),
            ),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: AppErrorRetry(
              message: '학습별 통계를 불러오지 못했어요',
              onRetry: () => ref.invalidate(studyOverviewProvider),
            ),
          ),
        );
  }
}

class _StudyOverviewContent extends StatelessWidget {
  const _StudyOverviewContent({required this.overview});

  final StudyOverview overview;

  @override
  Widget build(BuildContext context) {
    final format = MaterialLocalizations.of(context).formatDecimal;
    final accuracy = overview.totalAnswers == 0
        ? '—'
        : format((overview.correctAnswers / overview.totalAnswers * 100)
            .round()
            .clamp(0, 100));

    var vocabulary = 0;
    var grammar = 0;
    var sentences = 0;
    final days = <StatsBarDay>[];
    for (final day in overview.daily) {
      final date = DateTime.tryParse(day.date);
      if (date == null) continue;
      vocabulary += day.vocabularyAnsweredCount;
      grammar += day.grammarAnsweredCount;
      sentences += day.sentenceArrangeAnsweredCount;
      days.add(StatsBarDay(
        date: date,
        label: '${date.month}/${date.day}',
        counts: (
          vocabulary: day.vocabularyAnsweredCount,
          grammar: day.grammarAnsweredCount,
          sentences: day.sentenceArrangeAnsweredCount,
        ),
      ));
    }
    final total = vocabulary + grammar + sentences;
    final dateRange = days.isEmpty
        ? ''
        : '${_shortDate(days.first.date)}~${_shortDate(days.last.date)}';

    return Column(
      children: [
        _StudySection(
          title: '누적 학습 요약',
          child: _MetricCard(
            metrics: [
              _SummaryMetric(
                label: '퀴즈 완료',
                value: format(overview.quizzesCompleted),
                unit: '회',
                icon: _StudyMetricIcon.quiz,
              ),
              _SummaryMetric(
                label: '정답률',
                value: accuracy,
                unit: overview.totalAnswers == 0 ? '' : '%',
                icon: _StudyMetricIcon.accuracy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        _StudySection(
          title: '카테고리별 학습량',
          child: _CategoryCard(
            total: total,
            categories: [
              ('단어', vocabulary, AppColors.redesignVocabulary),
              ('문법', grammar, AppColors.redesignGrammar),
              ('문장배열', sentences, AppColors.redesignSentence),
            ],
          ),
        ),
        const SizedBox(height: 40),
        _StudySection(
          title: '일별 학습량',
          detail: '최근 7일',
          child: StatsBarChart(
            dateRangeLabel: dateRange,
            days: days,
            emptyMessage: total == 0 ? '최근 7일간 문제풀이 기록이 없어요' : null,
          ),
        ),
        const SizedBox(height: 40),
        _StudySection(
          title: '회화',
          child: _MetricCard(
            outlined: true,
            metrics: [
              _SummaryMetric(
                label: '총 대화 수',
                value: format(overview.conversationCount),
                unit: '회',
                icon: _StudyMetricIcon.conversation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _shortDate(DateTime date) => '${date.month}.${date.day}';
}

class _StudySection extends StatelessWidget {
  const _StudySection({
    required this.title,
    required this.child,
    this.detail,
  });

  final String title;
  final Widget child;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    final title = Semantics(
      header: true,
      child: Text(
        this.title,
        style: _statsText(context, 16, weight: FontWeight.w600),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail == null)
          title
        else
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSizes.sm,
            children: [
              title,
              Text(detail, style: _statsText(context, 13, muted: true)),
            ],
          ),
        const SizedBox(height: AppSizes.gap),
        child,
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metrics, this.outlined = false});

  final List<_SummaryMetric> metrics;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final outline =
        isLight ? AppColors.redesignOutline : theme.colorScheme.outlineVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: outlined
            ? theme.colorScheme.surfaceContainerLowest
            : isLight
                ? AppColors.redesignSurface
                : theme.colorScheme.surfaceContainerHigh,
        border: outlined ? Border.all(color: outline) : null,
        borderRadius: BorderRadius.circular(AppSizes.gap),
      ),
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: outlined ? 81 : 79),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  if (i > 0)
                    SizedBox(width: 1, child: ColoredBox(color: outline)),
                  Expanded(child: metrics[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _StudyMetricIcon {
  quiz('assets/icons/figma-stats-study-quiz.png'),
  accuracy('assets/icons/figma-stats-study-accuracy.png'),
  conversation('assets/icons/figma-stats-study-conversation.png');

  const _StudyMetricIcon(this.asset);

  final String asset;
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final _StudyMetricIcon icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            icon.asset,
            width: AppSizes.iconLg,
            height: AppSizes.iconLg,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: AppSizes.xs),
          Text.rich(
            TextSpan(
              text: value,
              children: [
                TextSpan(
                  text: unit,
                  style: _statsText(context, 13),
                ),
              ],
            ),
            style: _statsText(context, 18, weight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: _statsText(context, 11, muted: true),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.total, required this.categories});

  final int total;
  final List<(String, int, Color)> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = MaterialLocalizations.of(context).formatDecimal;
    final outline = theme.brightness == Brightness.light
        ? AppColors.redesignOutline
        : theme.colorScheme.outlineVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 101),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.gap,
            vertical: AppSizes.sm,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (index, (label, count, color))
                  in categories.indexed) ...[
                if (index > 0) const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Expanded(
                        child: Text(label, style: _statsText(context, 13))),
                    const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSizes.sm,
                        children: [
                          Text('${format(count)}개',
                              style: _statsText(context, 13)),
                          Text(
                            '${total > 0 ? (count * 100 / total).round() : 0}%',
                            style: _statsText(context, 11, muted: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _statsText(
  BuildContext context,
  double size, {
  bool muted = false,
  FontWeight weight = FontWeight.w400,
}) {
  final theme = Theme.of(context);
  final isLight = theme.brightness == Brightness.light;
  return TextStyle(
    color: muted
        ? isLight
            ? AppColors.redesignMutedForeground
            : theme.colorScheme.onSurfaceVariant
        : isLight
            ? AppColors.redesignForeground
            : theme.colorScheme.onSurface,
    fontFamily: redesignFontFamily,
    fontSize: size,
    fontWeight: weight,
    height: 1.4,
    letterSpacing: size * -0.025,
  );
}

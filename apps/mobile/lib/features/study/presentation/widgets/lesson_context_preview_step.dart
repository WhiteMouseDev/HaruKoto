import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../data/learning_goals.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_stage_actions.dart';
import 'lesson_vocab_preview_row.dart';

class LessonContextPreviewStep extends StatelessWidget {
  const LessonContextPreviewStep({
    super.key,
    required this.detail,
    required this.onNext,
    this.jlptLevel,
    this.stationNo,
  });

  final LessonDetailModel detail;
  final VoidCallback onNext;
  final String? jlptLevel;
  final int? stationNo;

  List<VocabItemModel> get _uniqueVocab {
    final seen = <(String, String)>{};
    return detail.vocabItems
        .where((item) => seen.add((item.word, item.reading)))
        .toList();
  }

  List<GrammarItemModel> get _uniqueGrammar {
    final seen = <String>{};
    return detail.grammarItems
        .where((item) => seen.add(item.normalizedPatternKey))
        .toList();
  }

  void _showAllVocabSheet(BuildContext context, List<VocabItemModel> items) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: AppSizes.sheetShape,
      builder: (context) => _LessonVocabPreviewSheet(items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final colors = theme.colorScheme;
    final vocab = _uniqueVocab;
    final grammar = _uniqueGrammar;
    final scene = detail.content.reading.scene?.trim();
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final secondary =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pageHorizontal,
              AppSizes.md,
              AppSizes.pageHorizontal,
              AppSizes.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LessonMetadata(
                  level: jlptLevel,
                  stationNo: stationNo,
                  lessonNo: detail.lessonNo,
                  chapterLessonNo: detail.chapterLessonNo,
                  minutes: detail.estimatedMinutes,
                ),
                const SizedBox(height: AppSizes.sm),
                Semantics(
                  header: true,
                  child: Text(
                    detail.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: redesignFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                _LessonGoalCard(topic: detail.topic),
                if (vocab.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.xl),
                  Row(
                    children: [
                      const Expanded(
                        child: _SectionTitle(text: '핵심 단어 미리보기'),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: light
                              ? AppColors.redesignControl
                              : colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: AppSizes.xs,
                          ),
                          child: Text(
                            '총 ${vocab.length}개',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: redesignFontFamily,
                              color: secondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.gap),
                  for (final item in vocab.take(5)) ...[
                    LessonVocabPreviewRow(vocab: item),
                    const SizedBox(height: AppSizes.gap),
                  ],
                  if (vocab.length > 5)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _showAllVocabSheet(context, vocab),
                        icon: const Icon(LucideIcons.list, size: 18),
                        label: Text('전체 ${vocab.length}개 보기'),
                      ),
                    ),
                ],
                if (grammar.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.lg),
                  const _SectionTitle(text: '배울 문법'),
                  const SizedBox(height: AppSizes.gap),
                  for (final item in grammar.take(3)) ...[
                    _LessonGrammarOverview(item: item),
                    const SizedBox(height: AppSizes.gap),
                  ],
                  if (grammar.length > 3)
                    Text(
                      '+${grammar.length - 3}개',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: redesignFontFamily,
                        color: secondary,
                      ),
                    ),
                ],
                if (scene != null && scene.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    scene,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: redesignFontFamily,
                      color: secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        LessonStageActions(nextLabel: '학습 시작', onNext: onNext),
      ],
    );
  }
}

class _LessonMetadata extends StatelessWidget {
  const _LessonMetadata({
    required this.level,
    required this.stationNo,
    required this.lessonNo,
    required this.chapterLessonNo,
    required this.minutes,
  });

  final String? level;
  final int? stationNo;
  final int lessonNo;
  final int chapterLessonNo;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final muted = light
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.bodySmall?.copyWith(
      fontFamily: redesignFontFamily,
      color: muted,
    );
    final label = stationNo != null && stationNo! > 0 && chapterLessonNo > 0
        ? '$stationNo번 역 · $chapterLessonNo번째 레슨'
        : lessonNo > 0
            ? '레슨 $lessonNo'
            : '레슨';
    final selectedLevel = level?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSizes.xs,
            runSpacing: AppSizes.xs,
            children: [
              if (selectedLevel != null && selectedLevel.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: light
                        ? AppColors.redesignVocabulary
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    child: Text(
                      selectedLevel,
                      style: style?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: light
                            ? AppColors.sakuraOn
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              Text(label, style: style),
            ],
          ),
        ),
        if (minutes > 0) ...[
          const SizedBox(width: AppSizes.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.clock, size: 14, color: muted),
              const SizedBox(width: AppSizes.xs),
              Text('$minutes분', style: style),
            ],
          ),
        ],
      ],
    );
  }
}

class _LessonGoalCard extends StatelessWidget {
  const _LessonGoalCard({required this.topic});

  final String topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: redesignFontFamily,
      fontSize: 14,
      color: light ? AppColors.redesignForeground : colors.onPrimaryContainer,
    );
    final goal = getLearningGoal(topic.trim());
    final emphasis = topic.trim();
    final accent = light ? AppColors.sakuraOn : colors.onPrimaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: light ? const Color(0xFFFAEEF0) : colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            Icon(
              LucideIcons.bookOpen,
              size: 18,
              color: light ? AppColors.brandPink : colors.onPrimaryContainer,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              '이번 레슨에서는',
              textAlign: TextAlign.center,
              style: style?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: AppSizes.xs),
            Text.rich(
              TextSpan(
                children: [
                  if (emphasis.isNotEmpty && goal.startsWith(emphasis)) ...[
                    TextSpan(
                      text: emphasis,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: goal.substring(emphasis.length)),
                  ] else
                    TextSpan(text: goal),
                ],
              ),
              textAlign: TextAlign.center,
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontFamily: redesignFontFamily,
          fontWeight: FontWeight.w700,
          color: theme.brightness == Brightness.light
              ? AppColors.redesignForeground
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _LessonGrammarOverview extends StatelessWidget {
  const _LessonGrammarOverview({required this.item});

  final GrammarItemModel item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: lessonPreviewRowDecoration(theme),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.pattern,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: redesignFontFamily,
                fontWeight: FontWeight.w700,
                color: light
                    ? AppColors.redesignForeground
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              item.meaningKo,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: redesignFontFamily,
                color: light
                    ? AppColors.redesignMutedForeground
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonVocabPreviewSheet extends StatelessWidget {
  const _LessonVocabPreviewSheet({required this.items});

  final List<VocabItemModel> items;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.56,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pageHorizontal,
              AppSizes.md,
              AppSizes.pageHorizontal,
              AppSizes.lg,
            ),
            itemCount: items.length + 1,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSizes.gap),
            itemBuilder: (context, index) {
              if (index > 0) {
                return LessonVocabPreviewRow(vocab: items[index - 1]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSheetHandle(),
                  const SizedBox(height: AppSizes.lg),
                  _SectionTitle(text: '배울 단어 ${items.length}개'),
                  const SizedBox(height: AppSizes.gap),
                  const Text('레슨에서 순서대로 만나게 될 표현입니다.'),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

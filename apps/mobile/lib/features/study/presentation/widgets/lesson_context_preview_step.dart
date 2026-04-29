import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../data/learning_goals.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_vocab_preview_chip.dart';

class LessonContextPreviewStep extends StatefulWidget {
  final LessonDetailModel detail;
  final VoidCallback onNext;

  const LessonContextPreviewStep({
    super.key,
    required this.detail,
    required this.onNext,
  });

  @override
  State<LessonContextPreviewStep> createState() =>
      _LessonContextPreviewStepState();
}

class _LessonContextPreviewStepState extends State<LessonContextPreviewStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.12).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  List<VocabItemModel> get _uniqueVocab {
    final seen = <String>{};
    return widget.detail.vocabItems.where((vocab) {
      final key = '${vocab.word}_${vocab.reading}';
      return seen.add(key);
    }).toList();
  }

  List<GrammarItemModel> get _uniqueGrammar {
    final seen = <String>{};
    return widget.detail.grammarItems.where((grammar) {
      return seen.add(grammar.normalizedPatternKey);
    }).toList();
  }

  void _showAllVocabSheet(
      BuildContext context, List<VocabItemModel> vocabItems) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: AppSizes.sheetShape,
      builder: (context) {
        return _LessonVocabPreviewSheet(vocabItems: vocabItems);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final theme = Theme.of(context);
    final reading = detail.content.reading;
    final learningGoal = getLearningGoal(detail.topic);
    final vocabItems = _uniqueVocab;
    final previewVocab = vocabItems.take(3).toList();
    final grammarItems = _uniqueGrammar;
    final remainingCount = vocabItems.length - previewVocab.length;
    final remainingGrammarCount = grammarItems.length - 3;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _staggered(
                  0,
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryStrong,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusFull),
                        ),
                        child: Text(
                          '레슨 ${detail.lessonNo}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.onGradient,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        LucideIcons.clock,
                        size: 14,
                        color: AppColors.lightSubtext,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${detail.estimatedMinutes}분',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.lightSubtext,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _staggered(
                  1,
                  Text(
                    detail.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightText,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                _staggered(
                  2,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.12),
                          AppColors.primary.withValues(alpha: 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.target,
                              size: 16,
                              color: AppColors.primaryStrong,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '이번 레슨을 끝내면',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.primaryStrong,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          learningGoal,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.lightText,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (reading.scene != null) ...[
                  const SizedBox(height: AppSizes.lg),
                  _staggered(
                    3,
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 14,
                          color: AppColors.lightSubtext,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reading.scene!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.lightSubtext,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.lg),
                if (previewVocab.isNotEmpty)
                  _staggered(
                    4,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.bookOpen,
                              size: 16,
                              color: AppColors.primaryStrong,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '핵심 단어 미리보기',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            LessonVocabCountPill(count: vocabItems.length),
                          ],
                        ),
                        const SizedBox(height: AppSizes.gap),
                        SizedBox(
                          height: LessonVocabPreviewChip.height,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: previewVocab.length +
                                (remainingCount > 0 ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSizes.sm),
                            itemBuilder: (context, index) {
                              if (index < previewVocab.length) {
                                return LessonVocabPreviewChip(
                                  vocab: previewVocab[index],
                                );
                              }
                              return LessonVocabPreviewMoreChip(
                                remainingCount: remainingCount,
                                totalCount: vocabItems.length,
                                onTap: () =>
                                    _showAllVocabSheet(context, vocabItems),
                              );
                            },
                          ),
                        ),
                        if (remainingCount > 0) ...[
                          const SizedBox(height: AppSizes.sm),
                          TextButton.icon(
                            onPressed: () =>
                                _showAllVocabSheet(context, vocabItems),
                            icon: const Icon(LucideIcons.list),
                            label: Text('전체 ${vocabItems.length}개 보기'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.lightSubtext,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (previewVocab.isNotEmpty && grammarItems.isNotEmpty)
                  Divider(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    height: AppSizes.xl,
                  ),
                if (grammarItems.isNotEmpty)
                  _staggered(
                    5,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.braces,
                              size: 16,
                              color: AppColors.primaryStrong,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '배울 문법',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.gap),
                        ...grammarItems.take(3).map(
                              (grammar) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSizes.sm,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSizes.gap),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightCard,
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusSm,
                                    ),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        grammar.pattern,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryStrong,
                                        ),
                                      ),
                                      const SizedBox(width: AppSizes.sm),
                                      Text(
                                        '—',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: AppColors.lightSubtext,
                                        ),
                                      ),
                                      const SizedBox(width: AppSizes.sm),
                                      Expanded(
                                        child: Text(
                                          grammar.meaningKo,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: AppColors.lightText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        if (remainingGrammarCount > 0)
                          Text(
                            '+$remainingGrammarCount개',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.lightSubtext,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton.icon(
                onPressed: widget.onNext,
                icon: const Icon(LucideIcons.sparkles),
                label: const Text('학습 시작하기'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LessonVocabPreviewSheet extends StatelessWidget {
  final List<VocabItemModel> vocabItems;

  const _LessonVocabPreviewSheet({required this.vocabItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.lg,
            ),
            itemCount: vocabItems.length + 1,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSizes.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSheetHandle(),
                    const SizedBox(height: AppSizes.lg),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.bookOpen,
                          size: 18,
                          color: AppColors.primaryStrong,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          '배울 단어 ${vocabItems.length}개',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.lightText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.gap),
                    Text(
                      '레슨에서 순서대로 만나게 될 표현입니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lightSubtext,
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                  ],
                );
              }

              return LessonVocabSheetRow(vocab: vocabItems[index - 1]);
            },
          ),
        );
      },
    );
  }
}

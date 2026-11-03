import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_result_actions.dart';
import 'lesson_result_question_card.dart';
import 'lesson_result_score_summary.dart';

class LessonResultStep extends StatefulWidget {
  final LessonSubmitResultModel result;
  final LessonDetailModel detail;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  const LessonResultStep({
    super.key,
    required this.result,
    required this.detail,
    required this.onRetry,
    required this.onDone,
  });

  @override
  State<LessonResultStep> createState() => _LessonResultStepState();
}

class _LessonResultStepState extends State<LessonResultStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;
  bool? _wrongOnly;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant LessonResultStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.id != widget.detail.id ||
        oldWidget.result != widget.result) {
      _wrongOnly = null;
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.1).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);
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

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final detail = widget.detail;
    final score = result.scoreTotal > 0
        ? (result.scoreCorrect / result.scoreTotal * 100).round()
        : 0;
    final isPerfect =
        result.scoreTotal > 0 && result.scoreCorrect == result.scoreTotal;
    final wrongCount = result.results.where((item) => !item.isCorrect).length;
    final wrongOnly = _wrongOnly ?? wrongCount > 0;
    final visibleResults = result.results
        .asMap()
        .entries
        .where((entry) => !wrongOnly || !entry.value.isCorrect)
        .toList(growable: false);
    final hasReviewMetadata = result.results
        .any((item) => item.stateAfter != null || item.nextReviewAt != null);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              const SizedBox(height: AppSizes.lg),
              _staggered(
                0,
                LessonResultScoreBadge(isPerfect: isPerfect),
              ),
              const SizedBox(height: AppSizes.md),
              _staggered(
                1,
                LessonResultScoreText(
                  score: score,
                  scoreCorrect: result.scoreCorrect,
                  scoreTotal: result.scoreTotal,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              if (result.srsItemsRegistered > 0)
                _staggered(
                  2,
                  LessonResultSrsBanner(
                    registeredCount: result.srsItemsRegistered,
                  ),
                ),
              const SizedBox(height: AppSizes.sm),
              Text(
                wrongCount > 0 ? '틀린 문항부터 확인해요' : '레슨 결과 다시 보기',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSizes.sm),
              Wrap(
                spacing: AppSizes.sm,
                runSpacing: AppSizes.xs,
                children: [
                  ChoiceChip(
                    key: const ValueKey('lesson-results-wrong'),
                    label: Text('오답만 $wrongCount'),
                    selected: wrongOnly,
                    onSelected: (_) => setState(() => _wrongOnly = true),
                  ),
                  ChoiceChip(
                    key: const ValueKey('lesson-results-all'),
                    label: Text('전체 ${result.results.length}'),
                    selected: !wrongOnly,
                    onSelected: (_) => setState(() => _wrongOnly = false),
                  ),
                ],
              ),
              if (hasReviewMetadata) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  '복습 정보는 제출 당시 기준이에요.\n'
                  '현재 복습 일정은 학습 탭에서 확인해 주세요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: AppSizes.sm),
              if (visibleResults.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                  child: Text(
                    wrongOnly && result.results.isNotEmpty
                        ? '틀린 문항이 없어요. 전체 보기에서 정답을 다시 확인해 보세요.'
                        : '문항별 결과가 없어 정답을 표시할 수 없어요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ...visibleResults.map((entry) {
                final lessonResult = entry.value;
                final matchingQuestions = detail.content.questions
                    .where((candidate) => candidate.order == lessonResult.order)
                    .toList(growable: false);
                final uniqueResultOrder = result.results
                        .where((candidate) =>
                            candidate.order == lessonResult.order)
                        .length ==
                    1;
                final question =
                    matchingQuestions.length == 1 && uniqueResultOrder
                        ? matchingQuestions.single
                        : null;
                return _staggered(
                  entry.key + 3,
                  LessonResultQuestionCard(
                    key: ValueKey(
                        'lesson-result-${entry.key}-${lessonResult.order}'),
                    result: lessonResult,
                    question: question,
                  ),
                );
              }),
            ],
          ),
        ),
        LessonResultActions(
          onDone: widget.onDone,
          onRetry: widget.onRetry,
        ),
      ],
    );
  }
}

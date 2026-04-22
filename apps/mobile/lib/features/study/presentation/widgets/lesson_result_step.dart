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
    final isPerfect = result.scoreCorrect == result.scoreTotal;

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
              ...result.results.asMap().entries.map((entry) {
                final lessonResult = entry.value;
                final question = detail.content.questions.firstWhere(
                  (candidate) => candidate.order == lessonResult.order,
                  orElse: () => detail.content.questions.first,
                );
                return _staggered(
                  entry.key + 3,
                  LessonResultQuestionCard(
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

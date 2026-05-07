import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

class LessonRecognitionCheckStep extends StatefulWidget {
  final List<LessonQuestionModel> questions;
  final int currentIndex;
  final int totalSteps;
  final ValueChanged<Map<String, dynamic>> onAnswer;

  const LessonRecognitionCheckStep({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.totalSteps,
    required this.onAnswer,
  });

  @override
  State<LessonRecognitionCheckStep> createState() =>
      _LessonRecognitionCheckStepState();
}

class _LessonRecognitionCheckStepState extends State<LessonRecognitionCheckStep>
    with SingleTickerProviderStateMixin {
  String? _selected;
  late List<QuizOptionModel> _shuffledOptions;
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _shuffleOptions();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant LessonRecognitionCheckStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _selected = null;
      _shuffleOptions();
      _entryController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _shuffleOptions() {
    final question = widget.questions[widget.currentIndex];
    _shuffledOptions = List.of(question.options ?? [])..shuffle(Random());
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.1).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  bool _hasAnswerKey(LessonQuestionModel question) =>
      question.correctAnswer != null && question.correctAnswer!.isNotEmpty;

  bool _isCorrectOption(LessonQuestionModel question, QuizOptionModel option) =>
      _hasAnswerKey(question) && option.id == question.correctAnswer;

  bool _isSelectedCorrect(LessonQuestionModel question) =>
      _hasAnswerKey(question) && _selected == question.correctAnswer;

  QuizOptionModel? _correctOption(LessonQuestionModel question) {
    if (!_hasAnswerKey(question)) return null;
    for (final option in question.options ?? const <QuizOptionModel>[]) {
      if (option.id == question.correctAnswer) return option;
    }
    return null;
  }

  Color _optionBgColor(LessonQuestionModel question, QuizOptionModel option) {
    if (_selected == null) return AppColors.lightCard;
    if (_selected == option.id) {
      if (!_hasAnswerKey(question)) return AppColors.sakuraTrack;
      return _isSelectedCorrect(question)
          ? AppColors.quizCorrectBg
          : AppColors.quizWrongBg;
    }
    if (_isCorrectOption(question, option)) {
      return AppColors.quizCorrectBg.withValues(alpha: 0.75);
    }
    return AppColors.lightCard;
  }

  Color _optionBorderColor(
    LessonQuestionModel question,
    QuizOptionModel option,
  ) {
    if (_selected == null) return AppColors.lightBorder;
    if (_selected == option.id) {
      if (!_hasAnswerKey(question)) return AppColors.sakura;
      return _isSelectedCorrect(question)
          ? AppColors.quizCorrectText
          : AppColors.quizWrongText;
    }
    if (_isCorrectOption(question, option)) return AppColors.quizCorrectText;
    return AppColors.lightBorder;
  }

  IconData? _optionIcon(LessonQuestionModel question, QuizOptionModel option) {
    if (_selected == null) return null;
    if (_selected == option.id) {
      if (!_hasAnswerKey(question)) return LucideIcons.check;
      return _isSelectedCorrect(question)
          ? LucideIcons.checkCircle2
          : LucideIcons.xCircle;
    }
    if (_isCorrectOption(question, option)) return LucideIcons.checkCircle2;
    return null;
  }

  Color _optionIconColor(LessonQuestionModel question, QuizOptionModel option) {
    if (_selected == option.id && _hasAnswerKey(question)) {
      return _isSelectedCorrect(question)
          ? AppColors.quizCorrectText
          : AppColors.quizWrongText;
    }
    if (_isCorrectOption(question, option)) return AppColors.quizCorrectText;
    return AppColors.sakura;
  }

  void _select(String id) {
    setState(() => _selected = id);
  }

  void _continue() {
    final selected = _selected;
    if (selected == null) return;
    widget.onAnswer({
      'order': widget.questions[widget.currentIndex].order,
      'selectedAnswer': selected,
      'responseMs': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.questions[widget.currentIndex];
    final selectedCorrect = _isSelectedCorrect(question);
    final correctOption = _correctOption(question);
    final feedbackAccent = !_hasAnswerKey(question)
        ? AppColors.sakura
        : selectedCorrect
            ? AppColors.quizCorrectText
            : AppColors.quizWrongText;
    final feedbackBg = !_hasAnswerKey(question)
        ? AppColors.sakuraTrack
        : selectedCorrect
            ? AppColors.quizCorrectBg
            : AppColors.quizWrongBg;
    final feedbackTitle = !_hasAnswerKey(question)
        ? '확인했어요'
        : selectedCorrect
            ? '정답이에요!'
            : '아쉬워요';

    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _staggered(
            0,
            Row(
              children: [
                Text(
                  '문항 ${widget.currentIndex + 1}/${widget.questions.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.lightSubtext,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '이해 체크',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.sakura,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          _staggered(
            1,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.sakuraTrack,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: AppColors.sakura.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                question.prompt,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightText,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          ..._shuffledOptions.asMap().entries.map((entry) {
            final option = entry.value;
            return _staggered(
              entry.key + 2,
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: GestureDetector(
                  onTap: _selected != null ? null : () => _select(option.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: _optionBgColor(question, option),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(
                        color: _optionBorderColor(question, option),
                        width: _selected == option.id ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.lightText,
                            ),
                          ),
                        ),
                        if (_optionIcon(question, option) != null) ...[
                          const SizedBox(width: AppSizes.sm),
                          Icon(
                            _optionIcon(question, option),
                            size: 18,
                            color: _optionIconColor(question, option),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_selected != null) ...[
            const SizedBox(height: AppSizes.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.gap),
              decoration: BoxDecoration(
                color: feedbackBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                border:
                    Border.all(color: feedbackAccent.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    !_hasAnswerKey(question)
                        ? LucideIcons.lightbulb
                        : selectedCorrect
                            ? LucideIcons.checkCircle2
                            : LucideIcons.xCircle,
                    size: 16,
                    color: feedbackAccent,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feedbackTitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: feedbackAccent,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        if (!selectedCorrect && correctOption != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '정답: ${correctOption.text}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.lightText,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (question.explanation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            question.explanation!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.lightText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _selected == null ? null : _continue,
                icon: const Icon(LucideIcons.chevronRight),
                label: const Text('다음으로'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sakura,
                  disabledBackgroundColor:
                      AppColors.lightBorder.withValues(alpha: 0.5),
                  foregroundColor: AppColors.onGradient,
                  disabledForegroundColor: AppColors.lightSubtext,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

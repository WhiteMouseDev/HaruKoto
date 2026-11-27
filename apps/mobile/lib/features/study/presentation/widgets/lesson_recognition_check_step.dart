import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/lesson_models.dart';
import '../../domain/lesson_recognition_feedback.dart';
import 'lesson_stage_actions.dart';

const _optionHeight = 42.0;
// Keep the visible 12-point gap with a 48-point interaction area per choice.
const _optionGap = AppSizes.gap - (kMinInteractiveDimension - _optionHeight);

class LessonRecognitionCheckStep extends StatelessWidget {
  const LessonRecognitionCheckStep({
    super.key,
    required this.question,
    required this.currentIndex,
    required this.questionCount,
    required this.onSelectionChanged,
    required this.onConfirm,
    required this.onNext,
    this.optionOrder,
    this.selectedOptionId,
    this.confirmed = false,
    this.usesServerFeedback = false,
    this.feedbackPending = false,
    this.feedbackUnavailable = false,
    this.feedback,
    this.onRetryFeedback,
    this.onPrevious,
  });

  final LessonQuestionModel question;
  final int currentIndex;
  final int questionCount;
  final List<String>? optionOrder;
  final String? selectedOptionId;
  final bool confirmed;
  final bool usesServerFeedback;
  final bool feedbackPending;
  final bool feedbackUnavailable;
  final LessonRecognitionFeedback? feedback;
  final ValueChanged<String> onSelectionChanged;
  final VoidCallback onConfirm;
  final VoidCallback? onRetryFeedback;
  final VoidCallback onNext;
  final VoidCallback? onPrevious;

  List<QuizOptionModel> get _options {
    final options = question.options ?? const [];
    final order = optionOrder;
    if (order == null) return options;
    final remaining = {for (final option in options) option.id: option};
    return [
      for (final id in order)
        if (remaining.remove(id) case final option?) option,
      ...remaining.values,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final muted =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;
    final options = _options;
    final unavailable = usesServerFeedback && feedbackUnavailable;
    final grading = usesServerFeedback && feedbackPending && !unavailable;
    final correctAnswer =
        usesServerFeedback ? feedback?.correctAnswer : question.correctAnswer;
    final correctOption =
        options.where((option) => option.id == correctAnswer).firstOrNull;
    final grade = confirmed && !grading && !unavailable && correctOption != null
        ? (usesServerFeedback
            ? feedback?.isCorrect
            : selectedOptionId == correctAnswer)
        : null;
    final isLast = currentIndex == questionCount - 1;
    final nextLabel = confirmed
        ? (isLast ? '다음 학습' : '다음 문제')
        : (usesServerFeedback || correctOption != null ? '정답 확인' : '답안 확인');
    final status = switch (grade) {
      true => '정답이에요!',
      false => '아쉬워요',
      null when grading => '채점 중…',
      null when unavailable => '지금은 채점할 수 없어요. 레슨 결과를 확인해 주세요.',
      null when usesServerFeedback => '정오답을 확인하지 못했어요',
      null => '답안을 확인했어요',
    };
    final explanation = usesServerFeedback
        ? (grade != null ? feedback?.explanation : null)
        : question.explanation;
    final canRetry =
        usesServerFeedback && !grading && !unavailable && grade == null;
    const smallText = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: 12,
      height: 1.4,
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(question.order),
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pageHorizontal,
              AppSizes.md,
              AppSizes.pageHorizontal,
              AppSizes.md,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
              decoration: BoxDecoration(
                color: light
                    ? AppColors.redesignSurface
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: light
                                ? AppColors.redesignVocabulary
                                : colors.primaryContainer,
                            shape: const StadiumBorder(),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.sm,
                              vertical: 2,
                            ),
                            child: Text(
                              '이해 체크',
                              style: smallText.copyWith(
                                color: light
                                    ? Colors.white
                                    : colors.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            '문제 ${currentIndex + 1} / $questionCount',
                            textAlign: TextAlign.end,
                            style: smallText.copyWith(color: muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xl),
                  Text(
                    question.prompt,
                    textAlign: TextAlign.center,
                    style: smallText.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 54),
                  for (final (index, option) in options.indexed) ...[
                    if (index != 0) const SizedBox(height: _optionGap),
                    _RecognitionOption(
                      option: option,
                      selected: option.id == selectedOptionId,
                      status: grade != null && option.id == correctAnswer
                          ? _OptionStatus.correct
                          : option.id != selectedOptionId
                              ? _OptionStatus.plain
                              : grade == false
                                  ? _OptionStatus.wrong
                                  : _OptionStatus.selected,
                      onPressed: confirmed
                          ? null
                          : () => onSelectionChanged(option.id),
                    ),
                  ],
                  if (confirmed) ...[
                    const SizedBox(height: AppSizes.md),
                    Semantics(
                      liveRegion: true,
                      child: Column(
                        children: [
                          Text(
                            status,
                            textAlign: TextAlign.center,
                            style: smallText.copyWith(
                              color: grade == null
                                  ? muted
                                  : grade
                                      ? AppColors.success(theme.brightness)
                                      : AppColors.error(theme.brightness),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (grade == false && correctOption != null) ...[
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              '정답: ${correctOption.text}',
                              textAlign: TextAlign.center,
                              style: smallText.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (explanation?.trim() case final text?
                              when text.isNotEmpty) ...[
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              text,
                              textAlign: TextAlign.center,
                              style: smallText.copyWith(color: muted),
                            ),
                          ],
                          if (canRetry && onRetryFeedback != null)
                            TextButton(
                              onPressed: onRetryFeedback,
                              child: const Text('다시 확인'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        LessonStageActions(
          nextLabel: nextLabel,
          showPrevious: true,
          onPrevious: onPrevious,
          onNext: selectedOptionId == null || grading
              ? null
              : confirmed
                  ? onNext
                  : onConfirm,
          accentNext: confirmed && isLast,
          showNextChevron: confirmed,
        ),
      ],
    );
  }
}

enum _OptionStatus { plain, selected, correct, wrong }

class _RecognitionOption extends StatelessWidget {
  const _RecognitionOption({
    required this.option,
    required this.selected,
    required this.status,
    required this.onPressed,
  });

  final QuizOptionModel option;
  final bool selected;
  final _OptionStatus status;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final surface = light ? AppColors.lightCard : colors.surfaceContainerLowest;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final (background, outline) = switch (status) {
      _OptionStatus.plain => (
          surface,
          light ? AppColors.redesignOutline : colors.outlineVariant,
        ),
      _OptionStatus.selected => (
          surface,
          light ? AppColors.brandPink : colors.primary,
        ),
      _OptionStatus.correct => (
          light ? AppColors.quizCorrectBg : AppColors.quizCorrectBgDark,
          light ? AppColors.quizCorrect : AppColors.quizCorrectTextDark,
        ),
      _OptionStatus.wrong => (
          light ? AppColors.quizWrongBg : AppColors.quizWrongBgDark,
          light ? AppColors.quizWrongText : AppColors.quizWrongTextDark,
        ),
    };

    return Semantics(
      selected: selected,
      value: switch (status) {
        _OptionStatus.correct => '정답',
        _OptionStatus.wrong => '선택한 오답',
        _ => null,
      },
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background,
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          side: BorderSide(
            color: outline,
            width: status == _OptionStatus.selected ? 2 : 1,
          ),
          shape: const StadiumBorder(),
          minimumSize: const Size(double.infinity, _optionHeight),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.gap,
            vertical: AppSizes.sm,
          ),
          textStyle: const TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(option.text, textAlign: TextAlign.center),
      ),
    );
  }
}

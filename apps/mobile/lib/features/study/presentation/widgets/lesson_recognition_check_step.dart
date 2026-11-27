import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/lesson_models.dart';
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
    this.onPrevious,
  });

  final LessonQuestionModel question;
  final int currentIndex;
  final int questionCount;
  final List<String>? optionOrder;
  final String? selectedOptionId;
  final bool confirmed;
  final ValueChanged<String> onSelectionChanged;
  final VoidCallback onConfirm;
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
    final correctOption = options
        .where((option) => option.id == question.correctAnswer)
        .firstOrNull;
    final isLast = currentIndex == questionCount - 1;
    final nextLabel = confirmed
        ? (isLast ? '다음 학습' : '다음 문제')
        : (correctOption == null ? '답안 확인' : '정답 확인');
    final selectedCorrect =
        correctOption != null && selectedOptionId == correctOption.id;
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
                      status: confirmed && option.id == correctOption?.id
                          ? _OptionStatus.correct
                          : option.id != selectedOptionId
                              ? _OptionStatus.plain
                              : confirmed && correctOption != null
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
                            correctOption == null
                                ? '답안을 확인했어요'
                                : selectedCorrect
                                    ? '정답이에요!'
                                    : '아쉬워요',
                            textAlign: TextAlign.center,
                            style: smallText.copyWith(
                              color: correctOption == null
                                  ? muted
                                  : selectedCorrect
                                      ? AppColors.success(theme.brightness)
                                      : AppColors.error(theme.brightness),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (correctOption != null && !selectedCorrect) ...[
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
                          if (question.explanation?.trim()
                              case final explanation?
                              when explanation.isNotEmpty) ...[
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              explanation,
                              textAlign: TextAlign.center,
                              style: smallText.copyWith(color: muted),
                            ),
                          ],
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
          onNext: selectedOptionId == null
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

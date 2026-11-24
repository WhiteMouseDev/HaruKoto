import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/quiz_question_model.dart';

const _correct = Color(0xFF00C853);
const _wrong = Color(0xFFD32F2F);

class FourChoiceQuiz extends StatefulWidget {
  const FourChoiceQuiz({
    super.key,
    required this.question,
    required this.questionNumber,
    this.selectedOptionId,
    this.answered = false,
    this.isCorrect = false,
    this.showFurigana = true,
    required this.onSelect,
  });

  final QuizQuestionModel question;
  final int questionNumber;
  final String? selectedOptionId;
  final bool answered;
  final bool isCorrect;
  final bool showFurigana;
  final ValueChanged<String> onSelect;

  @override
  State<FourChoiceQuiz> createState() => _FourChoiceQuizState();
}

class _FourChoiceQuizState extends State<FourChoiceQuiz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(FourChoiceQuiz oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.answered &&
        !oldWidget.answered &&
        !widget.isCorrect &&
        !MediaQuery.disableAnimationsOf(context)) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final accent = light ? AppColors.brandPink : AppColors.sakuraContainer;
    final reading = widget.question.questionSubText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(500),
              color: light
                  ? AppColors.redesignVocabulary
                  : theme.colorScheme.surfaceContainerHigh,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                'Q${widget.questionNumber}',
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: -0.3,
                  color: light ? Colors.white : accent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Text(
          widget.question.questionText,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFamily: redesignFontFamily,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: -0.65,
            color: foreground,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.showFurigana &&
            reading != null &&
            reading != widget.question.questionText) ...[
          const SizedBox(height: 2),
          Text(
            reading,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: redesignFontFamily,
              fontSize: 14,
              height: 1.4,
              letterSpacing: -0.35,
              color: light
                  ? AppColors.redesignMutedForeground
                  : theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 2),
        Center(
          child: TtsPlayButton(
            vocabId: widget.question.questionId,
            iconSize: 20,
            iconColor: accent,
          ),
        ),
        const SizedBox(height: 21),
        Column(
          spacing: 6,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in widget.question.options)
              _buildOption(context, option),
          ],
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, QuizOption option) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final selected = widget.selectedOptionId == option.id;
    final correct =
        widget.answered && option.id == widget.question.correctOptionId;
    final wrong = widget.answered && selected && !correct;
    final stateColor = correct
        ? light
            ? _correct
            : AppColors.quizCorrectTextDark
        : wrong
            ? light
                ? _wrong
                : AppColors.quizWrongTextDark
            : null;
    final accent = stateColor ?? (selected ? AppColors.brandPink : null);
    final onSelect = widget.answered ? null : () => widget.onSelect(option.id);
    final semanticsLabel = correct
        ? '${option.text}, 정답'
        : wrong
            ? '${option.text}, 선택한 오답'
            : option.text;

    final tile = Semantics(
      container: true,
      label: semanticsLabel,
      button: true,
      enabled: onSelect != null,
      selected: selected,
      onTap: onSelect,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(500),
          onTap: onSelect,
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Ink(
              decoration: BoxDecoration(
                color: stateColor?.withValues(alpha: 0.08) ??
                    theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(500),
                border: Border.all(
                  color: accent ??
                      (light
                          ? AppColors.redesignOutline
                          : theme.colorScheme.outline),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 42),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Center(
                    child: Text(
                      option.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: redesignFontFamily,
                        fontSize: 14,
                        height: 1.4,
                        letterSpacing: -0.35,
                        color: light
                            ? AppColors.redesignForeground
                            : theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!wrong) return tile;
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: child,
      ),
      child: tile,
    );
  }
}

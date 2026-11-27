import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/haru_typography.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/haru_button_styles.dart';
import '../../data/models/quiz_question_model.dart';
import 'quiz_progress_bar.dart';
import 'special_quiz_flow_controller.dart';

class SentenceArrangeQuiz extends StatefulWidget {
  const SentenceArrangeQuiz({
    super.key,
    required this.questions,
    required this.onAnswer,
    required this.onComplete,
    this.initialAnsweredCount = 0,
    this.totalQuestions,
  });

  final List<QuizQuestionModel> questions;
  final void Function(String questionId, bool isCorrect) onAnswer;
  final VoidCallback onComplete;
  final int initialAnsweredCount;
  final int? totalQuestions;

  @override
  State<SentenceArrangeQuiz> createState() => _SentenceArrangeQuizState();
}

class _SentenceArrangeQuizState extends State<SentenceArrangeQuiz> {
  final _flow = SpecialQuizFlowController();
  final _selectedSlots = <int>[];
  late List<int> _bankSlots;

  QuizQuestionModel get _question => widget.questions[_flow.currentIndex];
  List<String> get _tokens => _question.tokens ?? const [];

  @override
  void initState() {
    super.initState();
    _setupQuestion();
  }

  void _setupQuestion() {
    // Slot IDs keep repeated tokens independently selectable.
    _bankSlots = List.generate(_tokens.length, (index) => index)
      ..shuffle(Random());
    _selectedSlots.clear();
  }

  void _selectToken(int slot) {
    if (_flow.answered || _selectedSlots.contains(slot)) return;
    setState(() => _selectedSlots.add(slot));
  }

  void _removeToken(int slot) {
    if (_flow.answered) return;
    setState(() => _selectedSlots.remove(slot));
  }

  void _checkAnswer() {
    if (_flow.answered || _selectedSlots.isEmpty) return;
    final userAnswer = _selectedSlots.map((slot) => _tokens[slot]).join();
    final isCorrect = userAnswer == _tokens.join();
    setState(() => _flow.answer(isCorrect: isCorrect));
    widget.onAnswer(_question.questionId, isCorrect);
  }

  void _next() {
    if (!_flow.answered) return;
    if (_flow.isLastQuestion(widget.questions.length)) {
      widget.onComplete();
      return;
    }

    setState(() {
      _flow.advance(widget.questions.length);
      _setupQuestion();
    });
  }

  bool _isCorrectPlacement(int slot, int position) =>
      _flow.isCorrect || _tokens[slot] == _tokens[position];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final outline = light ? AppColors.redesignOutline : colors.outlineVariant;
    final surface = light ? AppColors.lightCard : colors.surfaceContainerLowest;
    final total = widget.totalQuestions ?? widget.questions.length;
    final position = widget.initialAnsweredCount + _flow.currentIndex + 1;
    final answered = _flow.answered;
    final isCorrect = _flow.isCorrect;
    final tokenTextStyle = HaruTypography.krCompactButton.copyWith(
      // Figma uses Pretendard Medium and falls back to Noto Sans JP Medium
      // for glyphs outside Pretendard's character set.
      fontFamilyFallback: const [
        'Noto Sans JP Fallback',
        redesignJapaneseFontFamily,
      ],
      locale: const Locale('ja'),
      color: foreground,
    );
    final statusColor = isCorrect
        ? light
            ? _correctOutline
            : AppColors.quizCorrectTextDark
        : light
            ? AppColors.quizWrongText
            : AppColors.quizWrongTextDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSizes.pageHorizontalEdge,
          child: QuizProgressBar(
            progress: total == 0 ? 0 : position / total,
            currentQuestion: position,
            totalQuestions: total,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(_question.questionId),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  decoration: BoxDecoration(
                    color: light
                        ? AppColors.redesignSurface
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppSizes.gap),
                    border: Border.all(color: outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _question.koreanSentence ?? _question.questionText,
                        textAlign: TextAlign.center,
                        style: HaruTypography.krTitle3.copyWith(
                          fontFamily: redesignJapaneseFontFamily,
                          fontFamilyFallback: const [redesignFontFamily],
                          color: light
                              ? const Color(0xFF505050)
                              : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSizes.gap),
                      Container(
                        key: const ValueKey('sentence-arrange-answer-area'),
                        constraints: const BoxConstraints(minHeight: 54),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.gap,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(AppSizes.gap),
                          border: Border.all(color: outline),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            for (final (answerPosition, slot)
                                in _selectedSlots.indexed)
                              InkWell(
                                key: ValueKey('sentence-arrange-answer-$slot'),
                                onTap:
                                    answered ? null : () => _removeToken(slot),
                                child: Semantics(
                                  hint: answered ? null : '탭해서 선택 해제',
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: kMinInteractiveDimension,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppSizes.xs,
                                        0,
                                        AppSizes.xs,
                                        2,
                                      ),
                                      child: Center(
                                        widthFactor: 1,
                                        heightFactor: 1,
                                        child: Text(
                                          _tokens[slot],
                                          style: answered &&
                                                  !_isCorrectPlacement(
                                                      slot, answerPosition)
                                              ? tokenTextStyle.copyWith(
                                                  color: statusColor,
                                                )
                                              : tokenTextStyle,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // The tiles paint at 42pt, centered in their 48pt tap targets.
                const SizedBox(height: 16 - HaruButtonStyles.compactHitInset),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing:
                      AppSizes.sm - 2 * HaruButtonStyles.compactHitInset,
                  children: [
                    for (final slot in _bankSlots)
                      _bankToken(slot, tokenTextStyle),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (answered) ...[
                Semantics(
                  liveRegion: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCorrect
                            ? LucideIcons.checkCircle2
                            : LucideIcons.xCircle,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Flexible(
                        child: Text(
                          isCorrect ? '정답이에요!' : '아쉬워요!',
                          style: HaruTypography.krBody3.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
              ],
              FilledButton(
                key: const ValueKey('sentence-arrange-action'),
                onPressed: answered
                    ? _next
                    : _selectedSlots.isEmpty
                        ? null
                        : _checkAnswer,
                style: HaruButtonStyles.primary(
                  context,
                  size: HaruButtonSize.regular,
                ),
                child: Text(
                  answered
                      ? _flow.isLastQuestion(widget.questions.length)
                          ? '결과 보기'
                          : '다음 문제'
                      : '정답 확인',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bankToken(int slot, TextStyle textStyle) {
    final position = _selectedSlots.indexOf(slot);
    final placed = position != -1;
    final answered = _flow.answered;
    final grade =
        !answered || !placed ? null : _isCorrectPlacement(slot, position);

    return _SentenceBankToken(
      key: ValueKey('sentence-arrange-bank-$slot'),
      token: _tokens[slot],
      textStyle: textStyle,
      placed: placed,
      grade: grade,
      onTap: answered || placed ? null : () => _selectToken(slot),
    );
  }
}

const _correctFill = Color(0xFFEBFBF1);
const _correctOutline = Color(0xFF00C853);

class _SentenceBankToken extends StatelessWidget {
  const _SentenceBankToken({
    super.key,
    required this.token,
    required this.textStyle,
    required this.placed,
    required this.grade,
    required this.onTap,
  });

  final String token;
  final TextStyle textStyle;
  final bool placed;
  final bool? grade;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final (surface, outline) = switch (grade) {
      true => (
          light ? _correctFill : AppColors.quizCorrectBgDark,
          light ? _correctOutline : AppColors.quizCorrectTextDark,
        ),
      false => (
          light ? AppColors.quizWrongBg : AppColors.quizWrongBgDark,
          light ? AppColors.quizWrongText : AppColors.quizWrongTextDark,
        ),
      null => (
          placed
              ? light
                  ? AppColors.redesignControl
                  : colors.surfaceContainerHigh
              : light
                  ? AppColors.lightCard
                  : colors.surfaceContainerLowest,
          light ? AppColors.redesignOutline : colors.outlineVariant,
        ),
    };
    final foreground = placed && grade == null
        ? light
            ? const Color(0xFF999999)
            : colors.onSurfaceVariant
        : textStyle.color;
    final stateLabel = switch (grade) {
      true => '올바른 위치',
      false => '잘못된 위치',
      null => placed ? '답안에 배치됨' : null,
    };

    return Semantics(
      value: stateLabel,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          disabledBackgroundColor: surface,
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          side: BorderSide(color: outline),
          minimumSize: const Size(0, 42),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.xs),
          ),
          textStyle: textStyle,
        ),
        child: Text(token, textAlign: TextAlign.center),
      ),
    );
  }
}

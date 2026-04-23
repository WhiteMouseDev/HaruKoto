import 'package:flutter/material.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/sound_service.dart';
import '../../data/models/quiz_question_model.dart';
import 'matching_quiz_controller.dart';

/// 매칭 퀴즈: 한 라운드에 [pairsPerRound]개씩 진행
class MatchingQuiz extends StatefulWidget {
  final List<QuizQuestionModel> questions;
  final void Function(String questionId, bool isCorrect) onMatchResult;
  final VoidCallback onComplete;
  final int pairsPerRound;
  final bool showFurigana;

  const MatchingQuiz({
    super.key,
    required this.questions,
    required this.onMatchResult,
    required this.onComplete,
    this.pairsPerRound = 5,
    this.showFurigana = true,
  });

  @override
  State<MatchingQuiz> createState() => _MatchingQuizState();
}

class _MatchingQuizState extends State<MatchingQuiz> {
  late MatchingQuizController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  @override
  void didUpdateWidget(covariant MatchingQuiz oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questions != widget.questions ||
        oldWidget.pairsPerRound != widget.pairsPerRound) {
      _controller = _createController();
    }
  }

  MatchingQuizController _createController() {
    return MatchingQuizController(
      pairs: widget.questions.map(MatchingQuizPair.fromQuestion).toList(),
      pairsPerRound: widget.pairsPerRound,
    );
  }

  void _handleLeftTap(MatchingQuizPair pair) {
    MatchingQuizAttemptResult? result;
    setState(() {
      result = _controller.selectLeft(pair.id);
    });
    _handleAttemptResult(result);
  }

  void _handleRightTap(MatchingQuizPair pair) {
    MatchingQuizAttemptResult? result;
    setState(() {
      result = _controller.selectRight(pair.id);
    });
    _handleAttemptResult(result);
  }

  void _handleAttemptResult(MatchingQuizAttemptResult? result) {
    if (result == null) return;

    widget.onMatchResult(result.leftPair.id, result.isCorrect);
    if (result.isCorrect) {
      HapticService().light();
      SoundService().play(SoundType.match);
    } else {
      HapticService().heavy();
      SoundService().play(SoundType.wrong);
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      late MatchingQuizRoundOutcome outcome;
      setState(() {
        outcome = _controller.finishAttempt();
      });

      if (outcome == MatchingQuizRoundOutcome.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unmatchedPairs = _controller.unmatchedLeftPairs;
    final unmatchedRight = _controller.unmatchedRightPairs;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          '일본어와 뜻을 연결하세요',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              _controller.scoreLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (_controller.hasMultipleRounds) ...[
              const Spacer(),
              Text(
                _controller.roundLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(unmatchedPairs.length, (i) {
          final pair = unmatchedPairs[i];
          final right = unmatchedRight[i];
          final isLeftSelected = _controller.isLeftSelected(pair.id);
          final isRightSelected = _controller.isRightSelected(right.id);
          final tapEnabled = !_controller.isResolving;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left (Japanese)
                  Expanded(
                    child: _MatchTile(
                      text: pair.left,
                      subText: widget.showFurigana ? pair.reading : null,
                      isSelected: isLeftSelected,
                      isBold: true,
                      onTap: tapEnabled ? () => _handleLeftTap(pair) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right (Korean)
                  Expanded(
                    child: _MatchTile(
                      text: right.right,
                      isSelected: isRightSelected,
                      isBold: false,
                      onTap: tapEnabled ? () => _handleRightTap(right) : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MatchTile extends StatelessWidget {
  final String text;
  final String? subText;
  final bool isSelected;
  final bool isBold;
  final VoidCallback? onTap;

  const _MatchTile({
    required this.text,
    this.subText,
    required this.isSelected,
    required this.isBold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subText != null && subText != text) ...[
                  Text(
                    subText!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  text,
                  style: isBold
                      ? theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)
                      : theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

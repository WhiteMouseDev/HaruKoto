import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/quiz_question_model.dart';

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
  late List<_MatchPair> _allPairs;
  int _roundIndex = 0;
  int _totalCorrect = 0;

  // 현재 라운드 상태
  late List<_MatchPair> _currentPairs;
  late List<String> _shuffledRight;
  String? _selectedLeft;
  String? _selectedRight;
  final Set<String> _matched = {};

  @override
  void initState() {
    super.initState();
    _allPairs = widget.questions.map((q) {
      // Use matching-specific fields from API if available,
      // otherwise fall back to standard question/option format
      if (q.matchingWord != null && q.matchingMeaning != null) {
        return _MatchPair(
          id: q.questionId,
          left: q.matchingWord!,
          reading: q.questionSubText,
          right: q.matchingMeaning!,
        );
      }
      final correctOption =
          q.options.firstWhere((o) => o.id == q.correctOptionId);
      return _MatchPair(
        id: q.questionId,
        left: q.questionText,
        reading: q.questionSubText,
        right: correctOption.text,
      );
    }).toList();
    _startRound();
  }

  void _startRound() {
    final start = _roundIndex * widget.pairsPerRound;
    final end = (start + widget.pairsPerRound).clamp(0, _allPairs.length);
    _currentPairs = _allPairs.sublist(start, end);
    _shuffledRight = _currentPairs.map((p) => p.right).toList()
      ..shuffle(Random());
    _matched.clear();
    _selectedLeft = null;
    _selectedRight = null;
  }

  int get _totalRounds => (_allPairs.length / widget.pairsPerRound).ceil();

  void _handleLeftTap(String left) {
    setState(() {
      _selectedLeft = left;
      _checkMatch();
    });
  }

  void _handleRightTap(String right) {
    setState(() {
      _selectedRight = right;
      _checkMatch();
    });
  }

  void _checkMatch() {
    if (_selectedLeft == null || _selectedRight == null) return;

    final pair = _currentPairs.firstWhere((p) => p.left == _selectedLeft);
    final isCorrect = pair.right == _selectedRight;
    widget.onMatchResult(pair.id, isCorrect);

    if (isCorrect) {
      _totalCorrect++;
      _matched.add(pair.id);
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _selectedLeft = null;
        _selectedRight = null;
      });

      if (_matched.length == _currentPairs.length) {
        // 현재 라운드 완료
        if (_roundIndex + 1 < _totalRounds) {
          setState(() {
            _roundIndex++;
            _startRound();
          });
        } else {
          widget.onComplete();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unmatchedPairs =
        _currentPairs.where((p) => !_matched.contains(p.id)).toList();
    final unmatchedRight = _shuffledRight
        .where((r) => unmatchedPairs.any((p) => p.right == r))
        .toList();

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
              '$_totalCorrect/${_allPairs.length} 맞춤',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (_totalRounds > 1) ...[
              const Spacer(),
              Text(
                '라운드 ${_roundIndex + 1}/$_totalRounds',
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
          final isLeftSelected = _selectedLeft == pair.left;
          final isRightSelected = _selectedRight == right;

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
                      onTap: () => _handleLeftTap(pair.left),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right (Korean)
                  Expanded(
                    child: _MatchTile(
                      text: right,
                      isSelected: isRightSelected,
                      isBold: false,
                      onTap: () => _handleRightTap(right),
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
  final VoidCallback onTap;

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

class _MatchPair {
  final String id;
  final String left;
  final String? reading;
  final String right;
  const _MatchPair({
    required this.id,
    required this.left,
    this.reading,
    required this.right,
  });
}

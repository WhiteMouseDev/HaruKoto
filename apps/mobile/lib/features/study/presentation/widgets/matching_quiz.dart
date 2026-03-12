import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/quiz_question_model.dart';

class MatchingQuiz extends StatefulWidget {
  final List<QuizQuestionModel> questions;
  final void Function(String questionId, bool isCorrect) onMatchResult;
  final VoidCallback onComplete;

  const MatchingQuiz({
    super.key,
    required this.questions,
    required this.onMatchResult,
    required this.onComplete,
  });

  @override
  State<MatchingQuiz> createState() => _MatchingQuizState();
}

class _MatchingQuizState extends State<MatchingQuiz> {
  late List<_MatchPair> _pairs;
  late List<String> _shuffledRight;
  String? _selectedLeft;
  String? _selectedRight;
  final Set<String> _matched = {};
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _pairs = widget.questions.map((q) {
      final correctOption =
          q.options.firstWhere((o) => o.id == q.correctOptionId);
      return _MatchPair(
        id: q.questionId,
        left: q.questionText,
        right: correctOption.text,
      );
    }).toList();
    _shuffledRight = _pairs.map((p) => p.right).toList()..shuffle(Random());
  }

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

    final pair = _pairs.firstWhere((p) => p.left == _selectedLeft);
    final isCorrect = pair.right == _selectedRight;
    widget.onMatchResult(pair.id, isCorrect);

    if (isCorrect) {
      _correct++;
      _matched.add(pair.id);
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _selectedLeft = null;
        _selectedRight = null;
      });

      if (_matched.length == _pairs.length) {
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unmatchedPairs =
        _pairs.where((p) => !_matched.contains(p.id)).toList();
    final unmatchedRight = _shuffledRight
        .where((r) =>
            unmatchedPairs.any((p) => p.right == r))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '일본어와 뜻을 연결하세요',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$_correct/${_pairs.length} 맞춤',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column (Japanese)
            Expanded(
              child: Column(
                children: unmatchedPairs.map((pair) {
                  final isSelected = _selectedLeft == pair.left;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleLeftTap(pair.left),
                        child: Container(
                          width: double.infinity,
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
                          child: Text(
                            pair.left,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 12),
            // Right column (Korean)
            Expanded(
              child: Column(
                children: unmatchedRight.map((right) {
                  final isSelected = _selectedRight == right;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleRightTap(right),
                        child: Container(
                          width: double.infinity,
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
                          child: Text(
                            right,
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MatchPair {
  final String id;
  final String left;
  final String right;
  const _MatchPair({required this.id, required this.left, required this.right});
}

import 'package:flutter/material.dart';

import '../../data/models/lesson_models.dart';
import 'lesson_learning_card.dart';
import 'lesson_stage_actions.dart';

class LessonGrammarLearningStep extends StatefulWidget {
  final List<GrammarItemModel> grammarItems;
  final VoidCallback onNext;
  final VoidCallback? onBackToPrev;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  const LessonGrammarLearningStep({
    super.key,
    required this.grammarItems,
    required this.onNext,
    this.onBackToPrev,
    this.initialIndex = 0,
    this.onIndexChanged,
  });

  @override
  State<LessonGrammarLearningStep> createState() =>
      _LessonGrammarLearningStepState();
}

class _LessonGrammarLearningStepState extends State<LessonGrammarLearningStep> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  List<GrammarItemModel> get _uniqueGrammar {
    final seen = <String>{};
    return widget.grammarItems.where((grammar) {
      return seen.add(grammar.normalizedPatternKey);
    }).toList();
  }

  @override
  void didUpdateWidget(LessonGrammarLearningStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  void _goTo(int index) {
    setState(() => _currentIndex = index);
    widget.onIndexChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final items = _uniqueGrammar;
    if (items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.grammarItems.isEmpty) widget.onNext();
      });
      return const SizedBox.shrink();
    }

    final index = _currentIndex.clamp(0, items.length - 1);
    final item = items[index];
    final isLast = index == items.length - 1;
    final explanation = item.explanation.trim();

    return Column(
      children: [
        Expanded(
          child: LessonLearningCard(
            itemType: '문법',
            itemIndex: index,
            itemCount: items.length,
            term: item.pattern,
            meaning: item.meaningKo,
            explanation: explanation.isEmpty ? null : explanation,
            onPrevious: index > 0 ? () => _goTo(index - 1) : null,
            onNext: isLast ? null : () => _goTo(index + 1),
          ),
        ),
        LessonStageActions(
          nextLabel: '다음학습',
          compact: true,
          onPrevious: widget.onBackToPrev,
          onNext: isLast ? widget.onNext : null,
        ),
      ],
    );
  }
}

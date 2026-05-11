import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/study_provider.dart';
import 'free_quiz_selection.dart';
import 'free_quiz_sheet_content.dart';

/// Bottom sheet for "자유 퀴즈" — level, type, mode selection + start.
class FreeQuizSheet extends ConsumerStatefulWidget {
  final FreeQuizSelection initialSelection;

  const FreeQuizSheet({
    super.key,
    this.initialSelection = const FreeQuizSelection(),
  });

  @override
  ConsumerState<FreeQuizSheet> createState() => _FreeQuizSheetState();
}

class _FreeQuizSheetState extends ConsumerState<FreeQuizSheet> {
  late FreeQuizSelection _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialSelection;
  }

  void _submitSelection() {
    Navigator.pop(context, _selection);
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(
      quizStatsProvider((level: _selection.level, type: _selection.type)),
    );
    final stats = statsAsync.hasValue ? statsAsync.value : null;

    return FreeQuizSheetContent(
      selection: _selection,
      stats: stats,
      onLevelChanged: (level) {
        setState(() => _selection = _selection.copyWith(level: level));
      },
      onTypeChanged: (type) {
        setState(() => _selection = _selection.selectType(type));
      },
      onModeChanged: (mode) {
        setState(() => _selection = _selection.copyWith(mode: mode));
      },
      onStartQuiz: _submitSelection,
    );
  }
}

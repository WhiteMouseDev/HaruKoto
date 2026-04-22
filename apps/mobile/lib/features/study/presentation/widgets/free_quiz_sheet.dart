import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/study_provider.dart';
import '../quiz_launch.dart';
import 'free_quiz_selection.dart';
import 'free_quiz_sheet_content.dart';

/// Bottom sheet for "자유 퀴즈" — level, type, mode selection + start.
class FreeQuizSheet extends ConsumerStatefulWidget {
  const FreeQuizSheet({super.key});

  @override
  ConsumerState<FreeQuizSheet> createState() => _FreeQuizSheetState();
}

class _FreeQuizSheetState extends ConsumerState<FreeQuizSheet> {
  FreeQuizSelection _selection = const FreeQuizSelection();

  void _startQuiz() {
    Navigator.pop(context);
    openQuizPageForSession(
      context,
      quizType: _selection.type,
      jlptLevel: _selection.level,
      count: 10,
      mode: _selection.mode != 'normal' ? _selection.mode : null,
    );
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
      onStartQuiz: _startQuiz,
    );
  }
}

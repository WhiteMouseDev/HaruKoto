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
    final initial = widget.initialSelection;
    _selection = FreeQuizSelection.jlptLevels.contains(initial.level)
        ? initial
        : initial.copyWith(level: FreeQuizSelection.jlptLevels.first);
  }

  void _submitSelection() {
    Navigator.pop(context, _selection);
  }

  @override
  Widget build(BuildContext context) {
    final statsProvider =
        quizStatsProvider((level: _selection.level, type: _selection.type));
    final stats = ref.watch(statsProvider);

    return FreeQuizSheetContent(
      selection: _selection,
      stats: stats.value,
      statsLoading: stats.isLoading,
      onRetryStats: stats.hasError && !stats.isLoading
          ? () => ref.invalidate(statsProvider)
          : null,
      onLevelChanged: (level) {
        setState(() => _selection = _selection.copyWith(level: level));
      },
      onModeChanged: (mode) {
        setState(() => _selection = _selection.copyWith(mode: mode));
      },
      onStartQuiz: _submitSelection,
    );
  }
}

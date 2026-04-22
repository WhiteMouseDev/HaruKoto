import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/quiz_session_model.dart';
import 'free_quiz_settings_selectors.dart';
import 'free_quiz_summary_card.dart';

class FreeTab extends StatelessWidget {
  final String selectedLevel;
  final String selectedType;
  final String quizMode;
  final String modeLabel;
  final List<String> jlptLevels;
  final List<(String, String)> quizTypes;
  final AsyncValue<StudyStatsModel> statsAsync;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onStartQuiz;

  const FreeTab({
    super.key,
    required this.selectedLevel,
    required this.selectedType,
    required this.quizMode,
    required this.modeLabel,
    required this.jlptLevels,
    required this.quizTypes,
    required this.statsAsync,
    required this.onLevelChanged,
    required this.onTypeChanged,
    required this.onModeChanged,
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.hasValue ? statsAsync.value : null;

    return Column(
      children: [
        FreeQuizSettingsSelectors(
          selectedLevel: selectedLevel,
          selectedType: selectedType,
          jlptLevels: jlptLevels,
          quizTypes: quizTypes,
          onLevelChanged: onLevelChanged,
          onTypeChanged: onTypeChanged,
        ),
        const SizedBox(height: 16),
        FreeQuizSummaryCard(
          selectedLevel: selectedLevel,
          selectedType: selectedType,
          quizMode: quizMode,
          modeLabel: modeLabel,
          stats: stats,
          onModeChanged: onModeChanged,
          onStartQuiz: onStartQuiz,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'jlpt_level_selector.dart';
import 'quiz_type_selector.dart';

class FreeQuizSettingsSelectors extends StatelessWidget {
  final String selectedLevel;
  final String selectedType;
  final List<String> jlptLevels;
  final List<(String, String)> quizTypes;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onTypeChanged;

  const FreeQuizSettingsSelectors({
    super.key,
    required this.selectedLevel,
    required this.selectedType,
    required this.jlptLevels,
    required this.quizTypes,
    required this.onLevelChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        JlptLevelSelector(
          levels: jlptLevels,
          selected: selectedLevel,
          onChanged: onLevelChanged,
        ),
        const SizedBox(height: 12),
        QuizTypeSelector(
          quizTypes: quizTypes,
          selectedType: selectedType,
          onTypeChanged: onTypeChanged,
        ),
      ],
    );
  }
}

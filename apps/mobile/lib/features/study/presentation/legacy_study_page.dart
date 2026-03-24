import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_preferences_provider.dart';
import 'study_page.dart';
import 'widgets/study_tab_content.dart';

/// Standalone page wrapping the legacy StudyTabContent for a single category.
/// Navigated to via /study/legacy/:category.
class LegacyStudyPage extends ConsumerWidget {
  final String category;

  const LegacyStudyPage({super.key, required this.category});

  StudyCategory _parseCategory() {
    switch (category.toUpperCase()) {
      case 'VOCABULARY':
        return StudyCategory.vocabulary;
      case 'GRAMMAR':
        return StudyCategory.grammar;
      case 'SENTENCE':
        return StudyCategory.sentenceArrange;
      default:
        return StudyCategory.vocabulary;
    }
  }

  String _categoryTitle() {
    switch (category.toUpperCase()) {
      case 'VOCABULARY':
        return '단어';
      case 'GRAMMAR':
        return '문법';
      case 'SENTENCE':
        return '문장배열';
      default:
        return '학습';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jlptLevel = ref.watch(userPreferencesProvider).jlptLevel;
    final studyCategory = _parseCategory();

    return Scaffold(
      appBar: AppBar(title: Text(_categoryTitle())),
      body: StudyTabContent(
        category: studyCategory,
        jlptLevel: jlptLevel,
      ),
    );
  }
}

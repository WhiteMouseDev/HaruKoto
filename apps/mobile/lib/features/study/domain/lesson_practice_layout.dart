import 'dart:math';

import '../data/models/lesson_models.dart';
import 'lesson_flow_policy.dart';

/// Store the actual orders as well as the seed: reopening does not depend on a
/// later SDK's shuffle implementation or a widget's random-number consumption.
class LessonPracticeLayout {
  const LessonPracticeLayout({
    this.recognitionOptions = const {},
    this.matchingVocabIds = const [],
    this.matchingRightIndices = const [],
    this.reorderBanks = const {},
  });

  final Map<int, List<String>> recognitionOptions;
  final List<String> matchingVocabIds;
  final List<int> matchingRightIndices;
  final Map<int, List<String>> reorderBanks;

  factory LessonPracticeLayout.create(LessonDetailModel detail, int seed) {
    final random = Random(seed);
    final recognition = <int, List<String>>{};
    for (final question in lessonRecognitionQuestions(detail)) {
      recognition[question.order] = [
        for (final option in question.options ?? const <QuizOptionModel>[])
          option.id,
      ]..shuffle(random);
    }
    final seen = <String>{};
    final unique = detail.vocabItems
        .where((item) =>
            item.meaningKo.trim().isNotEmpty && seen.add(item.meaningKo.trim()))
        .toList()
      ..shuffle(random);
    final pairs = unique.take(4).map((item) => item.id).toList();
    final right = List<int>.generate(pairs.length, (index) => index)
      ..shuffle(random);
    final banks = <int, List<String>>{};
    for (final question in lessonReorderQuestions(detail)) {
      final tokens = question.tokens ?? const <String>[];
      final distractors = detail.vocabItems
          .map((item) => item.word)
          .where((word) => word.trim().isNotEmpty && !tokens.contains(word))
          .toSet()
          .toList()
        ..shuffle(random);
      banks[question.order] = [...tokens, ...distractors.take(3)]
        ..shuffle(random);
    }
    return LessonPracticeLayout(
      recognitionOptions: recognition,
      matchingVocabIds: pairs,
      matchingRightIndices: right,
      reorderBanks: banks,
    );
  }

  Map<String, Object?> toJson() => {
        'recognitionOptions': {
          for (final entry in recognitionOptions.entries)
            '${entry.key}': entry.value
        },
        'matchingVocabIds': matchingVocabIds,
        'matchingRightIndices': matchingRightIndices,
        'reorderBanks': {
          for (final entry in reorderBanks.entries) '${entry.key}': entry.value
        },
      };
}

List<VocabItemModel> uniqueLessonVocab(LessonDetailModel detail) {
  final seen = <String>{};
  return detail.vocabItems
      .where((item) => seen.add('${item.word}_${item.reading}'))
      .toList();
}

List<GrammarItemModel> uniqueLessonGrammar(LessonDetailModel detail) {
  final seen = <String>{};
  return detail.grammarItems
      .where((item) => seen.add(item.normalizedPatternKey))
      .toList();
}

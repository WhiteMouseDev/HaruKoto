enum DailyGoalCategory {
  vocabulary('VOCABULARY', '단어'),
  grammar('GRAMMAR', '문법'),
  sentence('SENTENCE', '문장배열');

  const DailyGoalCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

// OPENAPI_SCHEMA: CategoryGoalProgress
class CategoryGoalData {
  const CategoryGoalData({required this.target, required this.answeredCount});

  final int target;
  final int answeredCount;

  static CategoryGoalData? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final target = json['target'];
    final answeredCount = json['answeredCount'];
    if (target is! int ||
        target <= 0 ||
        answeredCount is! int ||
        answeredCount < 0) {
      return null;
    }
    return CategoryGoalData(target: target, answeredCount: answeredCount);
  }
}

// OPENAPI_SCHEMA: DailyCategoryGoals
class CategoryGoalsData {
  const CategoryGoalsData({
    required this.date,
    required this.vocabulary,
    required this.grammar,
    required this.sentence,
  });

  final String date;
  final CategoryGoalData vocabulary;
  final CategoryGoalData grammar;
  final CategoryGoalData sentence;

  CategoryGoalData forCategory(DailyGoalCategory category) =>
      switch (category) {
        DailyGoalCategory.vocabulary => vocabulary,
        DailyGoalCategory.grammar => grammar,
        DailyGoalCategory.sentence => sentence,
      };

  static CategoryGoalsData? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final date = parseGoalDate(json['date']);
    final vocabulary = CategoryGoalData.tryFromJson(json['vocabulary']);
    final grammar = CategoryGoalData.tryFromJson(json['grammar']);
    final sentence = CategoryGoalData.tryFromJson(json['sentence']);
    if (date == null ||
        vocabulary == null ||
        grammar == null ||
        sentence == null) {
      return null;
    }
    return CategoryGoalsData(
        date: date,
        vocabulary: vocabulary,
        grammar: grammar,
        sentence: sentence);
  }
}

String? parseGoalDate(Object? date) {
  if (date is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    return null;
  }
  final parsed = DateTime.tryParse(date);
  return parsed != null &&
          parsed.year >= 1 &&
          parsed.toIso8601String().substring(0, 10) == date
      ? date
      : null;
}

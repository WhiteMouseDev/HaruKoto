class LearnedWordModel {
  final String id;
  final String vocabularyId;
  final String word;
  final String reading;
  final String meaningKo;
  final String jlptLevel;
  final String? exampleSentence;
  final String? exampleTranslation;
  final int correctCount;
  final int incorrectCount;
  final int streak;
  final bool mastered;
  final String? lastReviewedAt;

  const LearnedWordModel({
    required this.id,
    required this.vocabularyId,
    required this.word,
    required this.reading,
    required this.meaningKo,
    required this.jlptLevel,
    this.exampleSentence,
    this.exampleTranslation,
    required this.correctCount,
    required this.incorrectCount,
    required this.streak,
    required this.mastered,
    this.lastReviewedAt,
  });

  int get totalAttempts => correctCount + incorrectCount;
  int get accuracy =>
      totalAttempts > 0 ? (correctCount * 100 ~/ totalAttempts) : 0;

  factory LearnedWordModel.fromJson(Map<String, dynamic> json) {
    return LearnedWordModel(
      id: json['id'] as String,
      vocabularyId: json['vocabularyId'] as String,
      word: json['word'] as String,
      reading: json['reading'] as String,
      meaningKo: json['meaningKo'] as String,
      jlptLevel: json['jlptLevel'] as String,
      exampleSentence: json['exampleSentence'] as String?,
      exampleTranslation: json['exampleTranslation'] as String?,
      correctCount: json['correctCount'] as int? ?? 0,
      incorrectCount: json['incorrectCount'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      mastered: json['mastered'] as bool? ?? false,
      lastReviewedAt: json['lastReviewedAt'] as String?,
    );
  }
}

class LearnedWordsSummary {
  final int totalLearned;
  final int mastered;
  final int learning;

  const LearnedWordsSummary({
    required this.totalLearned,
    required this.mastered,
    required this.learning,
  });

  factory LearnedWordsSummary.fromJson(Map<String, dynamic> json) {
    return LearnedWordsSummary(
      totalLearned: json['totalLearned'] as int? ?? 0,
      mastered: json['mastered'] as int? ?? 0,
      learning: json['learning'] as int? ?? 0,
    );
  }
}

class WrongEntryModel {
  final String id;
  final String vocabularyId;
  final String word;
  final String reading;
  final String meaningKo;
  final String jlptLevel;
  final String? exampleSentence;
  final String? exampleTranslation;
  final int correctCount;
  final int incorrectCount;
  final bool mastered;
  final String? lastReviewedAt;

  const WrongEntryModel({
    required this.id,
    required this.vocabularyId,
    required this.word,
    required this.reading,
    required this.meaningKo,
    required this.jlptLevel,
    this.exampleSentence,
    this.exampleTranslation,
    required this.correctCount,
    required this.incorrectCount,
    required this.mastered,
    this.lastReviewedAt,
  });

  int get totalAttempts => correctCount + incorrectCount;
  int get accuracy =>
      totalAttempts > 0 ? (correctCount * 100 ~/ totalAttempts) : 0;

  factory WrongEntryModel.fromJson(Map<String, dynamic> json) {
    return WrongEntryModel(
      id: json['id'] as String,
      vocabularyId: json['vocabularyId'] as String,
      word: json['word'] as String,
      reading: json['reading'] as String,
      meaningKo: json['meaningKo'] as String,
      jlptLevel: json['jlptLevel'] as String,
      exampleSentence: json['exampleSentence'] as String?,
      exampleTranslation: json['exampleTranslation'] as String?,
      correctCount: json['correctCount'] as int? ?? 0,
      incorrectCount: json['incorrectCount'] as int? ?? 0,
      mastered: json['mastered'] as bool? ?? false,
      lastReviewedAt: json['lastReviewedAt'] as String?,
    );
  }
}

class WrongAnswersSummary {
  final int totalWrong;
  final int mastered;
  final int remaining;

  const WrongAnswersSummary({
    required this.totalWrong,
    required this.mastered,
    required this.remaining,
  });

  factory WrongAnswersSummary.fromJson(Map<String, dynamic> json) {
    return WrongAnswersSummary(
      totalWrong: json['totalWrong'] as int? ?? 0,
      mastered: json['mastered'] as int? ?? 0,
      remaining: json['remaining'] as int? ?? 0,
    );
  }
}

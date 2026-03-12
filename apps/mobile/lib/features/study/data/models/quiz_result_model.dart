class GameEvent {
  final String type;
  final String title;
  final String body;
  final String emoji;

  const GameEvent({
    required this.type,
    required this.title,
    required this.body,
    required this.emoji,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
    );
  }
}

class QuizResultModel {
  final int correctCount;
  final int totalQuestions;
  final int xpEarned;
  final int accuracy;
  final int currentXp;
  final int xpForNext;
  final int level;
  final List<GameEvent> events;

  const QuizResultModel({
    required this.correctCount,
    required this.totalQuestions,
    required this.xpEarned,
    required this.accuracy,
    required this.currentXp,
    required this.xpForNext,
    required this.level,
    required this.events,
  });

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    return QuizResultModel(
      correctCount: json['correctCount'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? 0,
      accuracy: json['accuracy'] as int? ?? 0,
      currentXp: json['currentXp'] as int? ?? 0,
      xpForNext: json['xpForNext'] as int? ?? 100,
      level: json['level'] as int? ?? 1,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class WrongAnswerModel {
  final String questionId;
  final String word;
  final String? reading;
  final String meaningKo;
  final String? exampleSentence;
  final String? exampleTranslation;

  const WrongAnswerModel({
    required this.questionId,
    required this.word,
    this.reading,
    required this.meaningKo,
    this.exampleSentence,
    this.exampleTranslation,
  });

  factory WrongAnswerModel.fromJson(Map<String, dynamic> json) {
    return WrongAnswerModel(
      questionId: json['questionId'] as String,
      word: json['word'] as String,
      reading: json['reading'] as String?,
      meaningKo: json['meaningKo'] as String,
      exampleSentence: json['exampleSentence'] as String?,
      exampleTranslation: json['exampleTranslation'] as String?,
    );
  }
}

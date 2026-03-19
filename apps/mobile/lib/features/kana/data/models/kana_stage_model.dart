import '../../../study/data/models/quiz_result_model.dart';

class KanaStageModel {
  final String id;
  final String kanaType;
  final int stageNumber;
  final String title;
  final String description;
  final List<String> characters;
  final bool isUnlocked;
  final bool isCompleted;
  final int? quizScore;
  final String? completedAt;

  const KanaStageModel({
    required this.id,
    required this.kanaType,
    required this.stageNumber,
    required this.title,
    required this.description,
    required this.characters,
    required this.isUnlocked,
    required this.isCompleted,
    this.quizScore,
    this.completedAt,
  });

  factory KanaStageModel.fromJson(Map<String, dynamic> json) {
    return KanaStageModel(
      id: json['id'] as String,
      kanaType: json['kanaType'] as String,
      stageNumber: json['stageNumber'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      characters: (json['characters'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      quizScore: json['quizScore'] as int?,
      completedAt: json['completedAt'] as String?,
    );
  }
}

class QuizQuestion {
  final String questionId;
  final String questionText;
  final String? questionSubText;
  final List<QuizOption> options;
  final String correctOptionId;

  const QuizQuestion({
    required this.questionId,
    required this.questionText,
    this.questionSubText,
    required this.options,
    required this.correctOptionId,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      questionId: json['questionId'] as String,
      questionText: json['questionText'] as String,
      questionSubText: json['questionSubText'] as String?,
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      correctOptionId: json['correctOptionId'] as String,
    );
  }
}

class QuizOption {
  final String id;
  final String text;

  const QuizOption({required this.id, required this.text});

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['id'] as String,
      text: json['text'] as String,
    );
  }
}

class StartQuizResponse {
  final String? sessionId;
  final List<QuizQuestion> questions;
  final String? message;

  const StartQuizResponse({
    this.sessionId,
    required this.questions,
    this.message,
  });

  factory StartQuizResponse.fromJson(Map<String, dynamic> json) {
    return StartQuizResponse(
      sessionId: json['sessionId'] as String?,
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String?,
    );
  }
}

class CompleteQuizResponse {
  final int accuracy;
  final int xpEarned;
  final int currentXp;
  final int xpForNext;
  final int level;
  final List<GameEvent> events;

  const CompleteQuizResponse({
    required this.accuracy,
    required this.xpEarned,
    required this.currentXp,
    required this.xpForNext,
    required this.level,
    required this.events,
  });

  factory CompleteQuizResponse.fromJson(Map<String, dynamic> json) {
    return CompleteQuizResponse(
      accuracy: json['accuracy'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? 0,
      currentXp: json['currentXp'] as int? ?? 0,
      xpForNext: json['xpForNext'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

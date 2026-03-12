class IncompleteSessionModel {
  final String id;
  final String quizType;
  final String jlptLevel;
  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final String startedAt;

  const IncompleteSessionModel({
    required this.id,
    required this.quizType,
    required this.jlptLevel,
    required this.totalQuestions,
    required this.answeredCount,
    required this.correctCount,
    required this.startedAt,
  });

  factory IncompleteSessionModel.fromJson(Map<String, dynamic> json) {
    return IncompleteSessionModel(
      id: json['id'] as String,
      quizType: json['quizType'] as String,
      jlptLevel: json['jlptLevel'] as String,
      totalQuestions: json['totalQuestions'] as int,
      answeredCount: json['answeredCount'] as int,
      correctCount: json['correctCount'] as int,
      startedAt: json['startedAt'] as String,
    );
  }
}

class StudyStatsModel {
  final int totalCount;
  final int studiedCount;
  final int progress;

  const StudyStatsModel({
    required this.totalCount,
    required this.studiedCount,
    required this.progress,
  });

  factory StudyStatsModel.fromJson(Map<String, dynamic> json) {
    return StudyStatsModel(
      totalCount: json['totalCount'] as int? ?? 0,
      studiedCount: json['studiedCount'] as int? ?? 0,
      progress: json['progress'] as int? ?? 0,
    );
  }
}

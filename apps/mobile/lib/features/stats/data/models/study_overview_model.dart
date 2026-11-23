import '../../../home/data/models/dashboard_model.dart';

// OPENAPI_SCHEMA: StudyOverviewResponse
class StudyOverview {
  const StudyOverview({
    required this.quizzesCompleted,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.conversationCount,
    required this.daily,
  });

  final int quizzesCompleted;
  final int correctAnswers;
  final int totalAnswers;
  final int conversationCount;
  final List<WeeklyQuestionStatEntry> daily;

  factory StudyOverview.fromJson(Map<String, dynamic> json) {
    final daily = WeeklyQuestionStatEntry.parseWeek(json['daily']);
    if (daily == null) {
      throw const FormatException('Invalid daily study overview');
    }

    int count(Object? value) {
      if (value is! int || value < 0) {
        throw const FormatException('Invalid study overview count');
      }
      return value;
    }

    return StudyOverview(
      quizzesCompleted: count(json['quizzesCompleted']),
      correctAnswers: count(json['correctAnswers']),
      totalAnswers: count(json['totalAnswers']),
      conversationCount: count(json['conversationCount']),
      daily: List.unmodifiable(daily),
    );
  }
}

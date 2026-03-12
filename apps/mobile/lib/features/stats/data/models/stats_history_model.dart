class StatsHistoryRecord {
  final String date;
  final int wordsStudied;
  final int quizzesCompleted;
  final int correctAnswers;
  final int totalAnswers;
  final int conversationCount;
  final int studyTimeSeconds;
  final int xpEarned;

  const StatsHistoryRecord({
    required this.date,
    required this.wordsStudied,
    required this.quizzesCompleted,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.conversationCount,
    required this.studyTimeSeconds,
    required this.xpEarned,
  });

  factory StatsHistoryRecord.fromJson(Map<String, dynamic> json) {
    return StatsHistoryRecord(
      date: json['date'] as String? ?? '',
      wordsStudied: json['wordsStudied'] as int? ?? 0,
      quizzesCompleted: json['quizzesCompleted'] as int? ?? 0,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      totalAnswers: json['totalAnswers'] as int? ?? 0,
      conversationCount: json['conversationCount'] as int? ?? 0,
      studyTimeSeconds: json['studyTimeSeconds'] as int? ?? 0,
      xpEarned: json['xpEarned'] as int? ?? 0,
    );
  }
}

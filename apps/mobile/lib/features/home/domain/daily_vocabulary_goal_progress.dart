import '../../../core/providers/study_clock_provider.dart';
import '../data/models/dashboard_model.dart';

class DailyVocabularyGoalProgress {
  const DailyVocabularyGoalProgress({this.answeredCount, required this.goal});

  final int? answeredCount;
  final int goal;

  double? get fraction => answeredCount == null || goal <= 0
      ? null
      : (answeredCount! / goal).clamp(0.0, 1.0);

  String? get percentage =>
      fraction == null ? null : '${(fraction! * 100).toStringAsFixed(0)}%';

  String get countLabel =>
      fraction == null ? '오늘 학습량 확인 필요' : '오늘 $answeredCount/$goal개';

  String? get remainingLabel => fraction == null
      ? null
      : answeredCount! >= goal
          ? '오늘 목표를 달성했어요'
          : '목표까지 ${goal - answeredCount!}개 남았어요';
}

DailyVocabularyGoalProgress resolveDailyVocabularyGoalProgress({
  required VocabularyGoalData? vocabularyGoal,
  required int dailyGoal,
  required DateTime studyDate,
}) {
  final valid = dailyGoal > 0 &&
      vocabularyGoal != null &&
      vocabularyGoal.answeredCount >= 0 &&
      vocabularyGoal.date == studyDateKey(studyDate);
  return DailyVocabularyGoalProgress(
    answeredCount: valid ? vocabularyGoal.answeredCount : null,
    goal: dailyGoal,
  );
}

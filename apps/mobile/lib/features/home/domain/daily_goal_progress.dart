import '../../../core/providers/study_clock_provider.dart';
import '../data/models/category_goals_model.dart';
import '../data/models/dashboard_model.dart';

class DailyGoalProgress {
  const DailyGoalProgress({this.answeredCount, required this.goal});

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

DailyGoalProgress resolveDailyGoalProgress({
  DailyGoalCategory category = DailyGoalCategory.vocabulary,
  CategoryGoalsData? categoryGoals,
  required VocabularyGoalData? vocabularyGoal,
  required int dailyGoal,
  required DateTime studyDate,
}) {
  final date = studyDateKey(studyDate);
  if (categoryGoals != null && categoryGoals.date == date) {
    final current = categoryGoals.forCategory(category);
    return DailyGoalProgress(
      goal: current.target,
      answeredCount: current.answeredCount,
    );
  }
  if (category != DailyGoalCategory.vocabulary || categoryGoals != null) {
    return const DailyGoalProgress(goal: 0);
  }
  final valid = dailyGoal > 0 &&
      vocabularyGoal != null &&
      vocabularyGoal.answeredCount >= 0 &&
      vocabularyGoal.date == date;
  return DailyGoalProgress(
    answeredCount: valid ? vocabularyGoal.answeredCount : null,
    goal: dailyGoal,
  );
}

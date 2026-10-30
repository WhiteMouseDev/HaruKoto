import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/domain/daily_vocabulary_goal_progress.dart';

void main() {
  for (final count in [0, 8, 20, 24]) {
    test('$count saved vocabulary answers use the same daily target', () {
      final result = _progress(count: count);
      expect(result.countLabel, '오늘 $count/20개');
      expect(result.fraction, (count / 20).clamp(0.0, 1.0));
      expect(result.percentage, '${(count / 20 * 100).clamp(0, 100).round()}%');
      expect(result.remainingLabel,
          count >= 20 ? '오늘 목표를 달성했어요' : '목표까지 ${20 - count}개 남았어요');
    });
  }

  test('missing data, another KST day and invalid targets stay unknown', () {
    for (final result in [
      _progress(date: '2026-10-29'),
      _progress(date: '2026-10-31'),
      _progress(count: -1),
      _progress(goal: 0),
      _progress(goal: -10),
      resolveDailyVocabularyGoalProgress(
        vocabularyGoal: null,
        dailyGoal: 20,
        studyDate: DateTime.utc(2026, 10, 30),
      ),
    ]) {
      expect(result.fraction, isNull);
      expect(result.percentage, isNull);
      expect(result.countLabel, '오늘 학습량 확인 필요');
      expect(result.remainingLabel, isNull);
    }
  });
}

DailyVocabularyGoalProgress _progress({
  int count = 8,
  int goal = 20,
  String date = '2026-10-30',
}) =>
    resolveDailyVocabularyGoalProgress(
      vocabularyGoal: VocabularyGoalData(date: date, answeredCount: count),
      dailyGoal: goal,
      studyDate: DateTime.utc(2026, 10, 30),
    );

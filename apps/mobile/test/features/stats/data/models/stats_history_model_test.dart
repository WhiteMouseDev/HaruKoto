import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/stats/data/models/stats_history_model.dart';

void main() {
  group('StatsHistoryRecord', () {
    test('fromJson parses complete data', () {
      final json = {
        'date': '2024-01-15',
        'wordsStudied': 20,
        'quizzesCompleted': 5,
        'correctAnswers': 40,
        'totalAnswers': 50,
        'conversationCount': 3,
        'studyTimeSeconds': 3600,
        'xpEarned': 200,
      };
      final model = StatsHistoryRecord.fromJson(json);
      expect(model.date, '2024-01-15');
      expect(model.wordsStudied, 20);
      expect(model.quizzesCompleted, 5);
      expect(model.correctAnswers, 40);
      expect(model.totalAnswers, 50);
      expect(model.conversationCount, 3);
      expect(model.studyTimeSeconds, 3600);
      expect(model.xpEarned, 200);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = StatsHistoryRecord.fromJson({});
      expect(model.date, '');
      expect(model.wordsStudied, 0);
      expect(model.quizzesCompleted, 0);
      expect(model.correctAnswers, 0);
      expect(model.totalAnswers, 0);
      expect(model.conversationCount, 0);
      expect(model.studyTimeSeconds, 0);
      expect(model.xpEarned, 0);
    });
  });
}

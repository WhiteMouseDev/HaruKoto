import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/stats/data/models/stats_history_model.dart';

void main() {
  group('StatsHistoryRecord', () {
    test(
        'explicit activity flag is authoritative, including zero-count payloads',
        () {
      expect(StatsHistoryRecord.fromJson({'hasStudied': true}).hasStudyActivity,
          isTrue);
      expect(
          StatsHistoryRecord.fromJson(
                  {'hasStudied': false, 'xpEarned': 50, 'quizzesCompleted': 1})
              .hasStudyActivity,
          isFalse);
    });
    for (final field in [
      'wordsStudied',
      'quizzesCompleted',
      'conversationCount',
      'studyTimeSeconds',
      'xpEarned'
    ]) {
      test('legacy absent/null flag falls back to $field independently', () {
        for (final hasStudied in [
          <String, dynamic>{},
          {'hasStudied': null}
        ]) {
          expect(
              StatsHistoryRecord.fromJson({...hasStudied, field: 1})
                  .hasStudyActivity,
              isTrue);
          expect(
              StatsHistoryRecord.fromJson({...hasStudied, field: 0})
                  .hasStudyActivity,
              isFalse);
          expect(
              StatsHistoryRecord.fromJson({...hasStudied, field: -1})
                  .hasStudyActivity,
              isFalse);
        }
      });
      test('explicit false suppresses legacy positive $field', () {
        expect(
            StatsHistoryRecord.fromJson({'hasStudied': false, field: 1})
                .hasStudyActivity,
            isFalse);
      });
    }
    test('answer totals alone do not infer activity in an old response', () {
      expect(
          StatsHistoryRecord.fromJson({'correctAnswers': 2, 'totalAnswers': 3})
              .hasStudyActivity,
          isFalse);
    });
    test('new flag can represent server activity absent from legacy counters',
        () {
      for (final signal in [
        'kanaLearned',
        'grammarStudied',
        'sentencesStudied',
        'studyMinutes'
      ]) {
        final model =
            StatsHistoryRecord.fromJson({'hasStudied': true, signal: 1});
        expect(model.hasStudyActivity, isTrue);
        expect(model.wordsStudied, 0);
        expect(model.xpEarned, 0);
      }
    });
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
      expect(model.hasStudyActivity, true);
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
      expect(model.hasStudyActivity, false);
    });

    test('hasStudyActivity counts xp-only progress', () {
      final model = StatsHistoryRecord.fromJson({
        'date': '2024-01-15',
        'xpEarned': 25,
      });

      expect(model.hasStudyActivity, true);
    });
  });
}

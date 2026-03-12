import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';

void main() {
  group('IncompleteSessionModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'session-1',
        'quizType': 'vocabulary',
        'jlptLevel': 'N5',
        'totalQuestions': 20,
        'answeredCount': 10,
        'correctCount': 8,
        'startedAt': '2024-01-15T10:00:00Z',
      };
      final model = IncompleteSessionModel.fromJson(json);
      expect(model.id, 'session-1');
      expect(model.quizType, 'vocabulary');
      expect(model.jlptLevel, 'N5');
      expect(model.totalQuestions, 20);
      expect(model.answeredCount, 10);
      expect(model.correctCount, 8);
      expect(model.startedAt, '2024-01-15T10:00:00Z');
    });
  });

  group('StudyStatsModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'totalCount': 100,
        'studiedCount': 45,
        'progress': 45,
      };
      final model = StudyStatsModel.fromJson(json);
      expect(model.totalCount, 100);
      expect(model.studiedCount, 45);
      expect(model.progress, 45);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = StudyStatsModel.fromJson({});
      expect(model.totalCount, 0);
      expect(model.studiedCount, 0);
      expect(model.progress, 0);
    });
  });
}

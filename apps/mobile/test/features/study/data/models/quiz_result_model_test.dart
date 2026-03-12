import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';

void main() {
  group('QuizResultModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'correctCount': 8,
        'totalQuestions': 10,
        'xpEarned': 50,
        'accuracy': 80,
        'currentXp': 500,
        'xpForNext': 1000,
      };
      final model = QuizResultModel.fromJson(json);
      expect(model.correctCount, 8);
      expect(model.totalQuestions, 10);
      expect(model.xpEarned, 50);
      expect(model.accuracy, 80);
      expect(model.currentXp, 500);
      expect(model.xpForNext, 1000);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = QuizResultModel.fromJson({});
      expect(model.correctCount, 0);
      expect(model.totalQuestions, 0);
      expect(model.xpEarned, 0);
      expect(model.accuracy, 0);
      expect(model.currentXp, 0);
      expect(model.xpForNext, 100);
    });
  });

  group('WrongAnswerModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'questionId': 'q-1',
        'word': '食べる',
        'reading': 'たべる',
        'meaningKo': '먹다',
        'exampleSentence': '私はりんごを食べる',
        'exampleTranslation': '나는 사과를 먹는다',
      };
      final model = WrongAnswerModel.fromJson(json);
      expect(model.questionId, 'q-1');
      expect(model.word, '食べる');
      expect(model.reading, 'たべる');
      expect(model.meaningKo, '먹다');
      expect(model.exampleSentence, '私はりんごを食べる');
      expect(model.exampleTranslation, '나는 사과를 먹는다');
    });

    test('fromJson handles nullable fields', () {
      final json = {
        'questionId': 'q-2',
        'word': '走る',
        'meaningKo': '달리다',
      };
      final model = WrongAnswerModel.fromJson(json);
      expect(model.reading, isNull);
      expect(model.exampleSentence, isNull);
      expect(model.exampleTranslation, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/data/models/recommendation_model.dart';

void main() {
  group('QuizQuestionModel', () {
    test('parses from JSON correctly', () {
      final json = {
        'questionId': 'q1',
        'questionText': 'What is this?',
        'questionSubText': 'hint here',
        'options': [
          {'id': 'a', 'text': 'Option A'},
          {'id': 'b', 'text': 'Option B'},
        ],
        'correctOptionId': 'a',
      };

      final model = QuizQuestionModel.fromJson(json);
      expect(model.questionId, equals('q1'));
      expect(model.questionText, equals('What is this?'));
      expect(model.questionSubText, equals('hint here'));
      expect(model.options, hasLength(2));
      expect(model.options[0].id, equals('a'));
      expect(model.options[0].text, equals('Option A'));
      expect(model.correctOptionId, equals('a'));
    });

    test('handles optional cloze fields', () {
      final json = {
        'questionId': 'q2',
        'questionText': 'Fill the blank',
        'options': [
          {'id': 'a', 'text': 'X'},
        ],
        'correctOptionId': 'a',
        'sentence': '彼は___です',
        'translation': 'He is ___',
        'explanation': 'Grammar point',
        'grammarPoint': 'N5',
      };

      final model = QuizQuestionModel.fromJson(json);
      expect(model.sentence, equals('彼は___です'));
      expect(model.translation, equals('He is ___'));
      expect(model.explanation, equals('Grammar point'));
      expect(model.grammarPoint, equals('N5'));
    });

    test('handles sentence arrange fields', () {
      final json = {
        'questionId': 'q3',
        'questionText': 'Arrange',
        'options': <Map<String, dynamic>>[],
        'correctOptionId': '',
        'koreanSentence': '나는 학생입니다',
        'japaneseSentence': '私は学生です',
        'tokens': ['私', 'は', '学生', 'です'],
      };

      final model = QuizQuestionModel.fromJson(json);
      expect(model.koreanSentence, equals('나는 학생입니다'));
      expect(model.tokens, equals(['私', 'は', '学生', 'です']));
    });
  });

  group('IncompleteSessionModel', () {
    test('parses from JSON correctly', () {
      final json = {
        'id': 'session-1',
        'quizType': 'vocabulary',
        'jlptLevel': 'N5',
        'totalQuestions': 10,
        'answeredCount': 3,
        'correctCount': 2,
        'startedAt': '2024-01-01T00:00:00Z',
      };

      final model = IncompleteSessionModel.fromJson(json);
      expect(model.id, equals('session-1'));
      expect(model.quizType, equals('vocabulary'));
      expect(model.jlptLevel, equals('N5'));
      expect(model.totalQuestions, equals(10));
      expect(model.answeredCount, equals(3));
      expect(model.correctCount, equals(2));
    });
  });

  group('StudyStatsModel', () {
    test('parses from JSON correctly', () {
      final json = {
        'totalCount': 100,
        'studiedCount': 42,
        'progress': 42,
      };

      final model = StudyStatsModel.fromJson(json);
      expect(model.totalCount, equals(100));
      expect(model.studiedCount, equals(42));
      expect(model.progress, equals(42));
    });

    test('handles missing fields with defaults', () {
      final model = StudyStatsModel.fromJson({});
      expect(model.totalCount, equals(0));
      expect(model.studiedCount, equals(0));
      expect(model.progress, equals(0));
    });
  });

  group('QuizResultModel', () {
    test('parses full result with events', () {
      final json = {
        'correctCount': 8,
        'totalQuestions': 10,
        'xpEarned': 50,
        'accuracy': 80,
        'currentXp': 150,
        'xpForNext': 200,
        'level': 3,
        'events': [
          {
            'type': 'level_up',
            'title': 'Level Up!',
            'body': 'You reached level 3',
            'emoji': '🎉',
          },
        ],
      };

      final model = QuizResultModel.fromJson(json);
      expect(model.correctCount, equals(8));
      expect(model.totalQuestions, equals(10));
      expect(model.xpEarned, equals(50));
      expect(model.accuracy, equals(80));
      expect(model.level, equals(3));
      expect(model.events, hasLength(1));
      expect(model.events[0].type, equals('level_up'));
    });

    test('handles missing events', () {
      final model = QuizResultModel.fromJson({});
      expect(model.events, isEmpty);
      expect(model.correctCount, equals(0));
      expect(model.level, equals(1));
      expect(model.xpForNext, equals(100));
    });
  });

  group('RecommendationModel', () {
    test('parses from JSON', () {
      final json = {
        'reviewDueCount': 5,
        'newWordsCount': 20,
        'wrongCount': 3,
        'lastReviewedAt': '2024-01-01T00:00:00Z',
      };

      final model = RecommendationModel.fromJson(json);
      expect(model.reviewDueCount, equals(5));
      expect(model.newWordsCount, equals(20));
      expect(model.wrongCount, equals(3));
      expect(model.lastReviewedAt, isNotNull);
    });

    test('handles null lastReviewedAt', () {
      final model = RecommendationModel.fromJson({});
      expect(model.lastReviewText, isNull);
    });

    test('lastReviewText returns correct relative text', () {
      final today = DateTime.now().toIso8601String();
      final model = RecommendationModel.fromJson({
        'reviewDueCount': 0,
        'newWordsCount': 0,
        'wrongCount': 0,
        'lastReviewedAt': today,
      });
      expect(model.lastReviewText, equals('오늘'));

      final yesterday =
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      final model2 = RecommendationModel.fromJson({
        'reviewDueCount': 0,
        'newWordsCount': 0,
        'wrongCount': 0,
        'lastReviewedAt': yesterday,
      });
      expect(model2.lastReviewText, equals('어제'));

      final threeDaysAgo =
          DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
      final model3 = RecommendationModel.fromJson({
        'reviewDueCount': 0,
        'newWordsCount': 0,
        'wrongCount': 0,
        'lastReviewedAt': threeDaysAgo,
      });
      expect(model3.lastReviewText, equals('3일 전'));
    });
  });
}

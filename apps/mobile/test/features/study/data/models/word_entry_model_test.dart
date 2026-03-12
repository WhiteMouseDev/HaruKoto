import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/word_entry_model.dart';

void main() {
  group('LearnedWordModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'w-1',
        'vocabularyId': 'v-1',
        'word': '食べる',
        'reading': 'たべる',
        'meaningKo': '먹다',
        'jlptLevel': 'N5',
        'exampleSentence': '私はりんごを食べる',
        'exampleTranslation': '나는 사과를 먹는다',
        'correctCount': 10,
        'incorrectCount': 2,
        'streak': 5,
        'mastered': true,
        'lastReviewedAt': '2024-01-15T10:00:00Z',
      };
      final model = LearnedWordModel.fromJson(json);
      expect(model.id, 'w-1');
      expect(model.vocabularyId, 'v-1');
      expect(model.word, '食べる');
      expect(model.reading, 'たべる');
      expect(model.meaningKo, '먹다');
      expect(model.jlptLevel, 'N5');
      expect(model.exampleSentence, '私はりんごを食べる');
      expect(model.exampleTranslation, '나는 사과를 먹는다');
      expect(model.correctCount, 10);
      expect(model.incorrectCount, 2);
      expect(model.streak, 5);
      expect(model.mastered, true);
      expect(model.lastReviewedAt, '2024-01-15T10:00:00Z');
    });

    test('fromJson handles optional/default fields', () {
      final json = {
        'id': 'w-2',
        'vocabularyId': 'v-2',
        'word': '走る',
        'reading': 'はしる',
        'meaningKo': '달리다',
        'jlptLevel': 'N4',
      };
      final model = LearnedWordModel.fromJson(json);
      expect(model.exampleSentence, isNull);
      expect(model.exampleTranslation, isNull);
      expect(model.correctCount, 0);
      expect(model.incorrectCount, 0);
      expect(model.streak, 0);
      expect(model.mastered, false);
      expect(model.lastReviewedAt, isNull);
    });

    test('totalAttempts getter computes correctly', () {
      final model = LearnedWordModel.fromJson({
        'id': 'w-1',
        'vocabularyId': 'v-1',
        'word': 'w',
        'reading': 'r',
        'meaningKo': 'm',
        'jlptLevel': 'N5',
        'correctCount': 8,
        'incorrectCount': 2,
      });
      expect(model.totalAttempts, 10);
    });

    test('accuracy getter computes correctly', () {
      final model = LearnedWordModel.fromJson({
        'id': 'w-1',
        'vocabularyId': 'v-1',
        'word': 'w',
        'reading': 'r',
        'meaningKo': 'm',
        'jlptLevel': 'N5',
        'correctCount': 8,
        'incorrectCount': 2,
      });
      expect(model.accuracy, 80);
    });

    test('accuracy returns 0 when no attempts', () {
      final model = LearnedWordModel.fromJson({
        'id': 'w-1',
        'vocabularyId': 'v-1',
        'word': 'w',
        'reading': 'r',
        'meaningKo': 'm',
        'jlptLevel': 'N5',
      });
      expect(model.accuracy, 0);
    });
  });

  group('LearnedWordsSummary', () {
    test('fromJson parses complete data', () {
      final json = {'totalLearned': 50, 'mastered': 20, 'learning': 30};
      final model = LearnedWordsSummary.fromJson(json);
      expect(model.totalLearned, 50);
      expect(model.mastered, 20);
      expect(model.learning, 30);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = LearnedWordsSummary.fromJson({});
      expect(model.totalLearned, 0);
      expect(model.mastered, 0);
      expect(model.learning, 0);
    });
  });

  group('WrongEntryModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'we-1',
        'vocabularyId': 'v-1',
        'word': '難しい',
        'reading': 'むずかしい',
        'meaningKo': '어렵다',
        'jlptLevel': 'N4',
        'exampleSentence': '日本語は難しい',
        'exampleTranslation': '일본어는 어렵다',
        'correctCount': 3,
        'incorrectCount': 7,
        'mastered': false,
        'lastReviewedAt': '2024-01-15T10:00:00Z',
      };
      final model = WrongEntryModel.fromJson(json);
      expect(model.id, 'we-1');
      expect(model.vocabularyId, 'v-1');
      expect(model.word, '難しい');
      expect(model.reading, 'むずかしい');
      expect(model.meaningKo, '어렵다');
      expect(model.jlptLevel, 'N4');
      expect(model.correctCount, 3);
      expect(model.incorrectCount, 7);
      expect(model.mastered, false);
    });

    test('fromJson handles optional/default fields', () {
      final json = {
        'id': 'we-2',
        'vocabularyId': 'v-2',
        'word': 'w',
        'reading': 'r',
        'meaningKo': 'm',
        'jlptLevel': 'N5',
      };
      final model = WrongEntryModel.fromJson(json);
      expect(model.correctCount, 0);
      expect(model.incorrectCount, 0);
      expect(model.mastered, false);
      expect(model.lastReviewedAt, isNull);
    });

    test('totalAttempts and accuracy getters', () {
      final model = WrongEntryModel.fromJson({
        'id': 'we-1',
        'vocabularyId': 'v-1',
        'word': 'w',
        'reading': 'r',
        'meaningKo': 'm',
        'jlptLevel': 'N5',
        'correctCount': 3,
        'incorrectCount': 7,
      });
      expect(model.totalAttempts, 10);
      expect(model.accuracy, 30);
    });
  });

  group('WrongAnswersSummary', () {
    test('fromJson parses complete data', () {
      final json = {'totalWrong': 15, 'mastered': 5, 'remaining': 10};
      final model = WrongAnswersSummary.fromJson(json);
      expect(model.totalWrong, 15);
      expect(model.mastered, 5);
      expect(model.remaining, 10);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = WrongAnswersSummary.fromJson({});
      expect(model.totalWrong, 0);
      expect(model.mastered, 0);
      expect(model.remaining, 0);
    });
  });
}

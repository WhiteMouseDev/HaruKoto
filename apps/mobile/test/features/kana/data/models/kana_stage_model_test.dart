import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/data/models/kana_stage_model.dart';

void main() {
  group('KanaStageModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'stage-1',
        'kanaType': 'HIRAGANA',
        'stageNumber': 1,
        'title': 'Stage 1',
        'description': 'Learn basic vowels',
        'characters': ['あ', 'い', 'う', 'え', 'お'],
        'isUnlocked': true,
        'isCompleted': true,
        'quizScore': 90,
        'completedAt': '2024-01-15T10:00:00Z',
      };
      final model = KanaStageModel.fromJson(json);
      expect(model.id, 'stage-1');
      expect(model.kanaType, 'HIRAGANA');
      expect(model.stageNumber, 1);
      expect(model.title, 'Stage 1');
      expect(model.description, 'Learn basic vowels');
      expect(model.characters, ['あ', 'い', 'う', 'え', 'お']);
      expect(model.isUnlocked, true);
      expect(model.isCompleted, true);
      expect(model.quizScore, 90);
      expect(model.completedAt, '2024-01-15T10:00:00Z');
    });

    test('fromJson handles defaults for optional/boolean fields', () {
      final json = {
        'id': 'stage-2',
        'kanaType': 'KATAKANA',
        'stageNumber': 2,
        'title': 'Stage 2',
        'description': 'Ka row',
        'characters': ['カ', 'キ'],
      };
      final model = KanaStageModel.fromJson(json);
      expect(model.isUnlocked, false);
      expect(model.isCompleted, false);
      expect(model.quizScore, isNull);
      expect(model.completedAt, isNull);
    });
  });

  group('QuizQuestion (kana)', () {
    test('fromJson parses complete data', () {
      final json = {
        'questionId': 'kq-1',
        'questionText': 'What is this character?',
        'questionSubText': 'Hiragana',
        'options': [
          {'id': 'a', 'text': 'a'},
          {'id': 'b', 'text': 'i'},
        ],
        'correctOptionId': 'a',
      };
      final model = QuizQuestion.fromJson(json);
      expect(model.questionId, 'kq-1');
      expect(model.questionText, 'What is this character?');
      expect(model.questionSubText, 'Hiragana');
      expect(model.options.length, 2);
      expect(model.correctOptionId, 'a');
    });

    test('fromJson handles null questionSubText', () {
      final json = {
        'questionId': 'kq-2',
        'questionText': 'Test',
        'options': <dynamic>[],
        'correctOptionId': 'b',
      };
      final model = QuizQuestion.fromJson(json);
      expect(model.questionSubText, isNull);
    });
  });

  group('QuizOption (kana)', () {
    test('fromJson parses data', () {
      final json = {'id': 'opt-1', 'text': 'a'};
      final model = QuizOption.fromJson(json);
      expect(model.id, 'opt-1');
      expect(model.text, 'a');
    });
  });

  group('StartQuizResponse', () {
    test('fromJson parses complete data', () {
      final json = {
        'sessionId': 'sess-1',
        'questions': [
          {
            'questionId': 'q-1',
            'questionText': 'Q?',
            'options': [
              {'id': 'a', 'text': 'A'},
            ],
            'correctOptionId': 'a',
          },
        ],
        'message': 'Good luck!',
      };
      final model = StartQuizResponse.fromJson(json);
      expect(model.sessionId, 'sess-1');
      expect(model.questions.length, 1);
      expect(model.message, 'Good luck!');
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'questions': <dynamic>[],
      };
      final model = StartQuizResponse.fromJson(json);
      expect(model.sessionId, isNull);
      expect(model.questions, isEmpty);
      expect(model.message, isNull);
    });
  });

  group('CompleteQuizResponse', () {
    test('fromJson parses complete data', () {
      final json = {
        'accuracy': 90,
        'xpEarned': 100,
        'currentXp': 500,
        'xpForNext': 1000,
      };
      final model = CompleteQuizResponse.fromJson(json);
      expect(model.accuracy, 90);
      expect(model.xpEarned, 100);
      expect(model.currentXp, 500);
      expect(model.xpForNext, 1000);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = CompleteQuizResponse.fromJson({});
      expect(model.accuracy, 0);
      expect(model.xpEarned, 0);
      expect(model.currentXp, 0);
      expect(model.xpForNext, 0);
    });
  });
}

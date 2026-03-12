import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';

void main() {
  group('QuizOption', () {
    test('fromJson parses complete data', () {
      final json = {'id': 'opt-1', 'text': 'Answer A'};
      final model = QuizOption.fromJson(json);
      expect(model.id, 'opt-1');
      expect(model.text, 'Answer A');
    });
  });

  group('QuizQuestionModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'questionId': 'q-1',
        'questionText': 'What does this mean?',
        'questionSubText': 'Hint text',
        'hint': 'Think about greetings',
        'options': [
          {'id': 'a', 'text': 'Hello'},
          {'id': 'b', 'text': 'Goodbye'},
        ],
        'correctOptionId': 'a',
        'sentence': 'こんにちは',
        'translation': 'Hello',
        'explanation': 'Common greeting',
        'grammarPoint': 'N5',
        'koreanSentence': '안녕하세요',
        'japaneseSentence': 'こんにちは',
        'tokens': ['こんにちは'],
        'prompt': 'Translate this',
        'answer': 'こんにちは',
        'distractors': ['さようなら', 'ありがとう'],
      };
      final model = QuizQuestionModel.fromJson(json);
      expect(model.questionId, 'q-1');
      expect(model.questionText, 'What does this mean?');
      expect(model.questionSubText, 'Hint text');
      expect(model.hint, 'Think about greetings');
      expect(model.options.length, 2);
      expect(model.options[0].id, 'a');
      expect(model.correctOptionId, 'a');
      expect(model.sentence, 'こんにちは');
      expect(model.translation, 'Hello');
      expect(model.explanation, 'Common greeting');
      expect(model.grammarPoint, 'N5');
      expect(model.koreanSentence, '안녕하세요');
      expect(model.japaneseSentence, 'こんにちは');
      expect(model.tokens!.length, 1);
      expect(model.tokens![0], 'こんにちは');
      expect(model.prompt, 'Translate this');
      expect(model.answer, 'こんにちは');
      expect(model.distractors!.length, 2);
    });

    test('fromJson handles minimal required fields', () {
      final json = {
        'questionId': 'q-2',
        'questionText': 'Question',
        'options': <dynamic>[],
        'correctOptionId': 'a',
      };
      final model = QuizQuestionModel.fromJson(json);
      expect(model.questionId, 'q-2');
      expect(model.questionSubText, isNull);
      expect(model.hint, isNull);
      expect(model.options, isEmpty);
      expect(model.sentence, isNull);
      expect(model.tokens, isNull);
      expect(model.prompt, isNull);
      expect(model.answer, isNull);
      expect(model.distractors, isNull);
    });
  });
}

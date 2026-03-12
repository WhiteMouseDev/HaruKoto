import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/data/models/kana_character_model.dart';

void main() {
  group('KanaCharacterProgress', () {
    test('fromJson parses complete data', () {
      final json = {
        'correctCount': 10,
        'incorrectCount': 2,
        'streak': 5,
        'mastered': true,
        'lastReviewedAt': '2024-01-15T10:00:00Z',
      };
      final model = KanaCharacterProgress.fromJson(json);
      expect(model.correctCount, 10);
      expect(model.incorrectCount, 2);
      expect(model.streak, 5);
      expect(model.mastered, true);
      expect(model.lastReviewedAt, '2024-01-15T10:00:00Z');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = KanaCharacterProgress.fromJson({});
      expect(model.correctCount, 0);
      expect(model.incorrectCount, 0);
      expect(model.streak, 0);
      expect(model.mastered, false);
      expect(model.lastReviewedAt, isNull);
    });
  });

  group('KanaCharacterModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'kana-1',
        'kanaType': 'HIRAGANA',
        'character': 'あ',
        'romaji': 'a',
        'pronunciation': 'ah',
        'row': 'a-row',
        'column': '1',
        'strokeCount': 3,
        'exampleWord': 'あめ',
        'exampleReading': 'ame',
        'exampleMeaning': 'rain',
        'category': 'basic',
        'order': 1,
        'progress': {
          'correctCount': 5,
          'incorrectCount': 1,
          'streak': 3,
          'mastered': false,
        },
      };
      final model = KanaCharacterModel.fromJson(json);
      expect(model.id, 'kana-1');
      expect(model.kanaType, 'HIRAGANA');
      expect(model.character, 'あ');
      expect(model.romaji, 'a');
      expect(model.pronunciation, 'ah');
      expect(model.row, 'a-row');
      expect(model.column, '1');
      expect(model.strokeCount, 3);
      expect(model.exampleWord, 'あめ');
      expect(model.exampleReading, 'ame');
      expect(model.exampleMeaning, 'rain');
      expect(model.category, 'basic');
      expect(model.order, 1);
      expect(model.progress, isNotNull);
      expect(model.progress!.correctCount, 5);
    });

    test('fromJson handles defaults and null progress', () {
      final json = {
        'id': 'kana-2',
        'kanaType': 'KATAKANA',
        'character': 'ア',
        'romaji': 'a',
        'pronunciation': 'ah',
        'row': 'a-row',
        'column': '1',
      };
      final model = KanaCharacterModel.fromJson(json);
      expect(model.strokeCount, 0);
      expect(model.exampleWord, isNull);
      expect(model.exampleReading, isNull);
      expect(model.exampleMeaning, isNull);
      expect(model.category, 'basic');
      expect(model.order, 0);
      expect(model.progress, isNull);
    });
  });
}

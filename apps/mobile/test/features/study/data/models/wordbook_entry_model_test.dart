import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/wordbook_entry_model.dart';

void main() {
  group('WordbookEntryModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'wb-1',
        'word': '勉強',
        'reading': 'べんきょう',
        'meaningKo': '공부',
        'source': 'CHAT',
        'note': 'Important word',
        'createdAt': '2024-01-15T10:00:00Z',
      };
      final model = WordbookEntryModel.fromJson(json);
      expect(model.id, 'wb-1');
      expect(model.word, '勉強');
      expect(model.reading, 'べんきょう');
      expect(model.meaningKo, '공부');
      expect(model.source, 'CHAT');
      expect(model.note, 'Important word');
      expect(model.createdAt, '2024-01-15T10:00:00Z');
    });

    test('fromJson handles default source and null note', () {
      final json = {
        'id': 'wb-2',
        'word': '学校',
        'reading': 'がっこう',
        'meaningKo': '학교',
        'createdAt': '2024-01-16T10:00:00Z',
      };
      final model = WordbookEntryModel.fromJson(json);
      expect(model.source, 'MANUAL');
      expect(model.note, isNull);
    });
  });
}

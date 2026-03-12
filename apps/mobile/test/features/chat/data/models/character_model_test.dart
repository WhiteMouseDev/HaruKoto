import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/models/character_model.dart';

void main() {
  group('CharacterListItem', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'char-1',
        'name': 'Yuki',
        'nameJa': 'ゆき',
        'nameRomaji': 'Yuki',
        'gender': 'female',
        'description': 'A friendly student',
        'relationship': 'friend',
        'speechStyle': 'polite',
        'targetLevel': 'N5',
        'tier': 'free',
        'unlockCondition': null,
        'isDefault': true,
        'avatarEmoji': '👩',
        'avatarUrl': 'https://example.com/yuki.png',
        'gradient': 'linear-gradient(pink, white)',
        'order': 1,
      };
      final model = CharacterListItem.fromJson(json);
      expect(model.id, 'char-1');
      expect(model.name, 'Yuki');
      expect(model.nameJa, 'ゆき');
      expect(model.nameRomaji, 'Yuki');
      expect(model.gender, 'female');
      expect(model.description, 'A friendly student');
      expect(model.relationship, 'friend');
      expect(model.speechStyle, 'polite');
      expect(model.targetLevel, 'N5');
      expect(model.tier, 'free');
      expect(model.unlockCondition, isNull);
      expect(model.isDefault, true);
      expect(model.avatarEmoji, '👩');
      expect(model.avatarUrl, 'https://example.com/yuki.png');
      expect(model.gradient, 'linear-gradient(pink, white)');
      expect(model.order, 1);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = {'id': 'char-2'};
      final model = CharacterListItem.fromJson(json);
      expect(model.name, '');
      expect(model.nameJa, '');
      expect(model.nameRomaji, '');
      expect(model.gender, '');
      expect(model.description, '');
      expect(model.relationship, '');
      expect(model.speechStyle, '');
      expect(model.targetLevel, '');
      expect(model.tier, '');
      expect(model.unlockCondition, isNull);
      expect(model.isDefault, false);
      expect(model.avatarEmoji, '');
      expect(model.avatarUrl, isNull);
      expect(model.gradient, isNull);
      expect(model.order, 0);
    });
  });
}

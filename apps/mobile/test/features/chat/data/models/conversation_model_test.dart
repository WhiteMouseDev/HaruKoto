import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/models/conversation_model.dart';

void main() {
  group('ConversationScenario', () {
    test('fromJson parses complete data', () {
      final json = {
        'title': 'Ordering Food',
        'titleJa': '料理を注文する',
        'category': 'restaurant',
        'difficulty': 'beginner',
      };
      final model = ConversationScenario.fromJson(json);
      expect(model.title, 'Ordering Food');
      expect(model.titleJa, '料理を注文する');
      expect(model.category, 'restaurant');
      expect(model.difficulty, 'beginner');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = ConversationScenario.fromJson({});
      expect(model.title, '');
      expect(model.titleJa, '');
      expect(model.category, '');
      expect(model.difficulty, '');
    });
  });

  group('ConversationCharacter', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'char-1',
        'name': 'Yuki',
        'nameJa': 'ゆき',
        'avatarEmoji': '👩',
        'avatarUrl': 'https://example.com/yuki.png',
      };
      final model = ConversationCharacter.fromJson(json);
      expect(model.id, 'char-1');
      expect(model.name, 'Yuki');
      expect(model.nameJa, 'ゆき');
      expect(model.avatarEmoji, '👩');
      expect(model.avatarUrl, 'https://example.com/yuki.png');
    });

    test('fromJson handles defaults', () {
      final json = {'id': 'char-2'};
      final model = ConversationCharacter.fromJson(json);
      expect(model.name, '');
      expect(model.nameJa, '');
      expect(model.avatarEmoji, '');
      expect(model.avatarUrl, isNull);
    });
  });

  group('ConversationModel', () {
    test('fromJson parses complete data with nested models', () {
      final json = {
        'id': 'conv-1',
        'type': 'VOICE',
        'createdAt': '2024-01-15T10:00:00Z',
        'endedAt': '2024-01-15T10:30:00Z',
        'messageCount': 15,
        'overallScore': 85,
        'scenario': {
          'title': 'Ordering',
          'titleJa': '注文',
          'category': 'restaurant',
          'difficulty': 'beginner',
        },
        'character': {
          'id': 'char-1',
          'name': 'Yuki',
          'nameJa': 'ゆき',
          'avatarEmoji': '👩',
        },
      };
      final model = ConversationModel.fromJson(json);
      expect(model.id, 'conv-1');
      expect(model.type, 'VOICE');
      expect(model.createdAt, '2024-01-15T10:00:00Z');
      expect(model.endedAt, '2024-01-15T10:30:00Z');
      expect(model.messageCount, 15);
      expect(model.overallScore, 85);
      expect(model.scenario, isNotNull);
      expect(model.scenario!.title, 'Ordering');
      expect(model.character, isNotNull);
      expect(model.character!.name, 'Yuki');
    });

    test('fromJson handles defaults and null nested models', () {
      final json = {
        'id': 'conv-2',
        'createdAt': '2024-01-15T10:00:00Z',
      };
      final model = ConversationModel.fromJson(json);
      expect(model.type, 'TEXT');
      expect(model.endedAt, isNull);
      expect(model.messageCount, 0);
      expect(model.overallScore, isNull);
      expect(model.scenario, isNull);
      expect(model.character, isNull);
    });
  });
}

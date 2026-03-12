import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/models/chat_message_model.dart';

void main() {
  group('MessageFeedback', () {
    test('fromJson parses complete data', () {
      final json = {
        'type': 'grammar',
        'original': '食べるます',
        'correction': '食べます',
        'explanationKo': '동사 활용이 잘못되었습니다',
      };
      final model = MessageFeedback.fromJson(json);
      expect(model.type, 'grammar');
      expect(model.original, '食べるます');
      expect(model.correction, '食べます');
      expect(model.explanationKo, '동사 활용이 잘못되었습니다');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = MessageFeedback.fromJson({});
      expect(model.type, '');
      expect(model.original, '');
      expect(model.correction, '');
      expect(model.explanationKo, '');
    });
  });

  group('ChatMessageModel', () {
    test('fromJson parses complete data with feedback', () {
      final json = {
        'id': 'msg-1',
        'role': 'user',
        'messageJa': 'こんにちは',
        'messageKo': '안녕하세요',
        'feedback': [
          {
            'type': 'grammar',
            'original': 'orig',
            'correction': 'corr',
            'explanationKo': 'expl',
          },
        ],
      };
      final model = ChatMessageModel.fromJson(json);
      expect(model.id, 'msg-1');
      expect(model.role, 'user');
      expect(model.messageJa, 'こんにちは');
      expect(model.messageKo, '안녕하세요');
      expect(model.feedback, isNotNull);
      expect(model.feedback!.length, 1);
      expect(model.feedback![0].type, 'grammar');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = ChatMessageModel.fromJson({});
      expect(model.id, '');
      expect(model.role, 'ai');
      expect(model.messageJa, '');
      expect(model.messageKo, isNull);
      expect(model.feedback, isNull);
    });

    test('copyWith creates new instance with overridden fields', () {
      final original = ChatMessageModel.fromJson({
        'id': 'msg-1',
        'role': 'user',
        'messageJa': 'Hello',
      });
      final copy = original.copyWith(messageKo: '안녕');
      expect(copy.id, 'msg-1');
      expect(copy.role, 'user');
      expect(copy.messageJa, 'Hello');
      expect(copy.messageKo, '안녕');
    });
  });

  group('VocabularyItem', () {
    test('fromJson parses complete data', () {
      final json = {
        'word': '食べる',
        'reading': 'たべる',
        'meaningKo': '먹다',
      };
      final model = VocabularyItem.fromJson(json);
      expect(model.word, '食べる');
      expect(model.reading, 'たべる');
      expect(model.meaningKo, '먹다');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = VocabularyItem.fromJson({});
      expect(model.word, '');
      expect(model.reading, '');
      expect(model.meaningKo, '');
    });
  });

  group('MessageResponse', () {
    test('fromJson parses complete data', () {
      final json = {
        'messageJa': 'こんにちは',
        'messageKo': '안녕하세요',
        'feedback': [
          {
            'type': 'grammar',
            'original': 'o',
            'correction': 'c',
            'explanationKo': 'e',
          },
        ],
        'hint': 'Try using polite form',
        'newVocabulary': [
          {'word': '食べる', 'reading': 'たべる', 'meaningKo': '먹다'},
        ],
      };
      final model = MessageResponse.fromJson(json);
      expect(model.messageJa, 'こんにちは');
      expect(model.messageKo, '안녕하세요');
      expect(model.feedback.length, 1);
      expect(model.hint, 'Try using polite form');
      expect(model.newVocabulary.length, 1);
      expect(model.newVocabulary[0].word, '食べる');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = MessageResponse.fromJson({});
      expect(model.messageJa, '');
      expect(model.messageKo, '');
      expect(model.feedback, isEmpty);
      expect(model.hint, isNull);
      expect(model.newVocabulary, isEmpty);
    });
  });

  group('StartConversationResponse', () {
    test('fromJson parses complete data', () {
      final json = {
        'conversationId': 'conv-1',
        'firstMessage': {
          'messageJa': 'いらっしゃいませ',
          'messageKo': '어서오세요',
          'hint': 'Greet back',
        },
      };
      final model = StartConversationResponse.fromJson(json);
      expect(model.conversationId, 'conv-1');
      expect(model.firstMessage.messageJa, 'いらっしゃいませ');
      expect(model.firstMessage.messageKo, '어서오세요');
      expect(model.firstMessage.hint, 'Greet back');
    });
  });

  group('FirstMessage', () {
    test('fromJson handles missing fields with defaults', () {
      final model = FirstMessage.fromJson({});
      expect(model.messageJa, '');
      expect(model.messageKo, '');
      expect(model.hint, isNull);
    });
  });
}

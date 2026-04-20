import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_message_handler.dart';

void main() {
  group('GeminiLiveMessageHandler', () {
    test('setupComplete emits the setup action', () {
      final handler = GeminiLiveMessageHandler();

      final actions = handler.handle({'setupComplete': {}});

      expect(actions.map((action) => action.type), [
        GeminiLiveMessageActionType.setupComplete,
      ]);
    });

    test('sessionResumptionUpdate emits the latest handle', () {
      final handler = GeminiLiveMessageHandler();

      final actions = handler.handle({
        'sessionResumptionUpdate': {'newHandle': 'resume-1'},
      });

      expect(actions.single.type,
          GeminiLiveMessageActionType.updateResumptionHandle);
      expect(actions.single.text, 'resume-1');
    });

    test('goAway emits reconnect action', () {
      final handler = GeminiLiveMessageHandler();

      final actions = handler.handle({'goAway': {}});

      expect(actions.single.type, GeminiLiveMessageActionType.reconnect);
    });

    test('serverContent produces ordered delta transcript and audio actions',
        () {
      final handler = GeminiLiveMessageHandler();

      final actions = handler.handle({
        'serverContent': {
          'inputTranscription': {'text': 'もしもし'},
          'outputTranscription': {'text': 'やっほー'},
          'modelTurn': {
            'parts': [
              {
                'inlineData': {'data': 'audio-1'},
              },
            ],
          },
          'turnComplete': true,
        },
      });

      expect(actions.map((action) => action.type), [
        GeminiLiveMessageActionType.aiTextDelta,
        GeminiLiveMessageActionType.transcriptEntry,
        GeminiLiveMessageActionType.audioChunk,
        GeminiLiveMessageActionType.transcriptEntry,
      ]);
      expect(actions[0].text, 'やっほー');
      expect(actions[1].transcriptEntry?.role, 'user');
      expect(actions[1].transcriptEntry?.text, 'もしもし');
      expect(actions[2].text, 'audio-1');
      expect(actions[3].transcriptEntry?.role, 'assistant');
      expect(actions[3].transcriptEntry?.text, 'やっほー');
      expect(handler.transcript.map((entry) => entry.text), [
        'もしもし',
        'やっほー',
      ]);
    });

    test('interrupted flushes pending assistant transcript', () {
      final handler = GeminiLiveMessageHandler();

      handler.handle({
        'serverContent': {
          'outputTranscription': {'text': '途中まで'},
        },
      });
      final actions = handler.handle({
        'serverContent': {'interrupted': true},
      });

      expect(actions.single.type, GeminiLiveMessageActionType.transcriptEntry);
      expect(actions.single.transcriptEntry?.role, 'assistant');
      expect(actions.single.transcriptEntry?.text, '途中まで');
    });

    test('flushPendingTranscript flushes buffered user and assistant text', () {
      final handler = GeminiLiveMessageHandler();

      handler.handle({
        'serverContent': {
          'inputTranscription': {'text': 'ユーザー'},
          'outputTranscription': {'text': 'AI'},
        },
      });
      final entries = handler.flushPendingTranscript();

      expect(entries.map((entry) => entry.role), ['user', 'assistant']);
      expect(entries.map((entry) => entry.text), ['ユーザー', 'AI']);
      expect(handler.transcript.length, 2);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_message_handler.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transcript.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transcript_emitter.dart';

void main() {
  group('GeminiLiveTranscriptEmitter', () {
    test('emit forwards runtime transcript entries', () {
      final emitted = <String>[];
      final emitter = GeminiLiveTranscriptEmitter(
        messageHandler: GeminiLiveMessageHandler(),
        emitEntry: (entry) => emitted.add('${entry.role}:${entry.text}'),
      );

      emitter.emit(const TranscriptEntry(role: 'assistant', text: 'やっほー'));

      expect(emitted, ['assistant:やっほー']);
    });

    test('flush emits pending transcript entries from the message handler', () {
      final handler = GeminiLiveMessageHandler();
      final emitted = <String>[];
      final emitter = GeminiLiveTranscriptEmitter(
        messageHandler: handler,
        emitEntry: (entry) => emitted.add('${entry.role}:${entry.text}'),
      );
      handler.handle({
        'serverContent': {
          'inputTranscription': {'text': 'ユーザー'},
          'outputTranscription': {'text': 'AI'},
        },
      });

      emitter.flush();

      expect(emitted, ['user:ユーザー', 'assistant:AI']);
      expect(handler.transcript.map((entry) => entry.text), ['ユーザー', 'AI']);
    });

    test('transcript getter flushes buffered entries before returning snapshot',
        () {
      final handler = GeminiLiveMessageHandler();
      final emitted = <String>[];
      final emitter = GeminiLiveTranscriptEmitter(
        messageHandler: handler,
        emitEntry: (entry) => emitted.add('${entry.role}:${entry.text}'),
      );
      handler.handle({
        'serverContent': {
          'inputTranscription': {'text': 'もしもし'},
        },
      });

      final transcript = emitter.transcript;

      expect(emitted, ['user:もしもし']);
      expect(transcript.map((entry) => entry.text), ['もしもし']);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_inbound_dispatcher.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_message_handler.dart';

void main() {
  group('GeminiLiveInboundDispatcher', () {
    test('dispatches setup resumption and reconnect actions', () {
      final recorder = _InboundEventRecorder();
      final dispatcher = _dispatcher(recorder);

      dispatcher.dispatch('{"setupComplete":{}}');
      dispatcher
          .dispatch('{"sessionResumptionUpdate":{"newHandle":"resume-1"}}');
      dispatcher.dispatch('{"goAway":{}}');

      expect(recorder.events, [
        'setupComplete',
        'resumption:resume-1',
        'reconnect',
      ]);
    });

    test('dispatches transcript text and audio actions in handler order', () {
      final recorder = _InboundEventRecorder();
      final dispatcher = _dispatcher(recorder);

      dispatcher.dispatch(jsonEncode({
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
      }));

      expect(recorder.events, [
        'aiText:やっほー',
        'transcript:user:もしもし',
        'audio:audio-1',
        'transcript:assistant:やっほー',
      ]);
    });

    test('ignores inactive malformed and unknown raw frames', () {
      final inactiveRecorder = _InboundEventRecorder();
      final inactiveDispatcher = _dispatcher(
        inactiveRecorder,
        isActive: () => false,
      );
      inactiveDispatcher.dispatch('{"setupComplete":{}}');

      final recorder = _InboundEventRecorder();
      final dispatcher = _dispatcher(recorder);
      dispatcher.dispatch(Object());
      dispatcher.dispatch('not json');

      expect(inactiveRecorder.events, isEmpty);
      expect(recorder.events, isEmpty);
    });
  });
}

GeminiLiveInboundDispatcher _dispatcher(
  _InboundEventRecorder recorder, {
  bool Function()? isActive,
}) {
  return GeminiLiveInboundDispatcher(
    messageHandler: GeminiLiveMessageHandler(),
    isActive: isActive ?? () => true,
    onSetupComplete: () => recorder.events.add('setupComplete'),
    onUpdateResumptionHandle: (handle) {
      recorder.events.add('resumption:$handle');
    },
    onReconnect: () => recorder.events.add('reconnect'),
    onAiTextDelta: (text) => recorder.events.add('aiText:$text'),
    onTranscriptEntry: (entry) {
      recorder.events.add('transcript:${entry.role}:${entry.text}');
    },
    onAudioChunk: (base64Data) => recorder.events.add('audio:$base64Data'),
  );
}

class _InboundEventRecorder {
  final events = <String>[];
}

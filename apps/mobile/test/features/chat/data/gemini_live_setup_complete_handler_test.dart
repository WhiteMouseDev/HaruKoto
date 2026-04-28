import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_greeting_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_outbound_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_setup_complete_handler.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveSetupCompleteHandler', () {
    test(
        'marks connected, prepares playback, and delays recording until the first model turn ends',
        () async {
      final events = <String>[];
      final reconnectCoordinator = GeminiLiveReconnectCoordinator();
      final firstDecision = reconnectCoordinator.requestReconnect();
      final transport = _RecordingGeminiLiveTransport(events);
      final handler = GeminiLiveSetupCompleteHandler(
        reconnectCoordinator: reconnectCoordinator,
        greetingSender: GeminiLiveGreetingSender(
          outboundSender: GeminiLiveOutboundSender(transport: transport),
          characterName: 'ハル',
          scenarioGreeting: 'カスタム挨拶',
        ),
        emitState: (state) => events.add('state:${state.name}'),
        preparePlayback: () {
          events.add('playback');
          return Future<bool>.value(true);
        },
        startRecording: () {
          events.add('recording');
          return Future<void>.value();
        },
      );

      handler.handle();
      await Future<void>.delayed(Duration.zero);
      final secondDecision = reconnectCoordinator.requestReconnect();

      expect(firstDecision.attempt, 1);
      expect(secondDecision.attempt, 1);
      expect(events, [
        'state:connected',
        'playback',
        'send',
      ]);

      handler.handleModelTurnComplete();
      handler.handleModelTurnComplete();

      expect(events, [
        'state:connected',
        'playback',
        'send',
        'recording',
      ]);
    });
  });
}

class _RecordingGeminiLiveTransport implements GeminiLiveTransport {
  _RecordingGeminiLiveTransport(this.events);

  final List<String> events;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect(
    Uri uri, {
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {}

  @override
  void send(String data) {
    events.add('send');
  }

  @override
  Future<void> close() async {}
}

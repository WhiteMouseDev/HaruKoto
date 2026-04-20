import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_connection_runner.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveConnectionRunner', () {
    test('connect builds URI and forwards messages and reconnect events',
        () async {
      final transport = _FakeGeminiLiveTransport();
      final messages = <dynamic>[];
      var reconnects = 0;
      final runner = GeminiLiveConnectionRunner(
        transport: transport,
        reconnectCoordinator: GeminiLiveReconnectCoordinator(),
        isActive: () => true,
        onMessage: messages.add,
        onReconnect: () => reconnects++,
      );

      await runner.connect(
        const GeminiLiveConnectionInput(
          wsUri: 'wss://example.test/live',
          token: 'token/with/slash',
          model: 'gemini-live',
        ),
      );

      final connection = transport.connections.single;
      expect(
        connection.uri.toString(),
        'wss://example.test/live?access_token=token/with/slash',
      );

      connection.onMessage('{"setupComplete":{}}');
      connection.onError(StateError('socket error'));
      connection.onDone();

      expect(messages, ['{"setupComplete":{}}']);
      expect(reconnects, 2);
    });

    test('ignores error and done events from stale connections', () async {
      final transport = _FakeGeminiLiveTransport();
      var reconnects = 0;
      final runner = GeminiLiveConnectionRunner(
        transport: transport,
        reconnectCoordinator: GeminiLiveReconnectCoordinator(),
        isActive: () => true,
        onMessage: (_) {},
        onReconnect: () => reconnects++,
      );

      await runner.connect(
        const GeminiLiveConnectionInput(
          wsUri: 'wss://example.test/live',
          token: 'first-token',
          model: 'gemini-live',
        ),
      );
      final staleConnection = transport.connections.single;

      await runner.connect(
        const GeminiLiveConnectionInput(
          wsUri: 'wss://example.test/live',
          token: 'second-token',
          model: 'gemini-live',
        ),
      );

      staleConnection.onError(StateError('stale error'));
      staleConnection.onDone();
      transport.connections.last.onError(StateError('current error'));

      expect(reconnects, 1);
    });

    test('does not reconnect from done when inactive', () async {
      final transport = _FakeGeminiLiveTransport();
      var reconnects = 0;
      final runner = GeminiLiveConnectionRunner(
        transport: transport,
        reconnectCoordinator: GeminiLiveReconnectCoordinator(),
        isActive: () => false,
        onMessage: (_) {},
        onReconnect: () => reconnects++,
      );

      await runner.connect(
        const GeminiLiveConnectionInput(
          wsUri: 'wss://example.test/live',
          token: 'token',
          model: 'gemini-live',
        ),
      );

      transport.connections.single.onDone();

      expect(reconnects, 0);
    });
  });
}

class _FakeGeminiLiveTransport implements GeminiLiveTransport {
  final connections = <_RecordedConnection>[];

  @override
  bool get isConnected => connections.isNotEmpty;

  @override
  Future<void> connect(
    Uri uri, {
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    connections.add(
      _RecordedConnection(
        uri: uri,
        onMessage: onMessage,
        onError: onError,
        onDone: onDone,
      ),
    );
  }

  @override
  void send(String data) {}

  @override
  Future<void> close() async {}
}

class _RecordedConnection {
  const _RecordedConnection({
    required this.uri,
    required this.onMessage,
    required this.onError,
    required this.onDone,
  });

  final Uri uri;
  final void Function(dynamic raw) onMessage;
  final void Function(Object error) onError;
  final void Function() onDone;
}

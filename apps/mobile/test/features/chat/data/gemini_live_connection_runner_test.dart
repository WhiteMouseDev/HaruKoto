import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_connection_runner.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_runner.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

const _input = GeminiLiveConnectionInput(
  wsUri: 'wss://example.test/live',
  token: 'token/with/slash',
  model: 'gemini-live',
);

void main() {
  group('GeminiLiveConnectionRunner', () {
    test('awaits setup after transport opens and forwards current messages',
        () async {
      final transport = _FakeGeminiLiveTransport();
      final messages = <dynamic>[];
      var reconnects = 0;
      var completed = false;
      final runner = GeminiLiveConnectionRunner(
        transport: transport,
        reconnectCoordinator: GeminiLiveReconnectCoordinator(),
        isActive: () => true,
        onMessage: messages.add,
        onReconnect: () => reconnects++,
      );
      final connecting = runner.connect(_input, sendSetup: () {}).then((_) {
        completed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      final connection = transport.connections.single;
      expect(connection.uri.toString(),
          'wss://example.test/live?access_token=token/with/slash');
      connection.onMessage('{"setupComplete":{}}');
      await connecting;
      connection.onError(StateError('socket error'));
      connection.onDone();
      expect(messages, ['{"setupComplete":{}}']);
      expect(reconnects, 1);
    });

    test('ignores messages and disconnects from stale connections', () async {
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
      await runner.connect(_input, sendSetup: transport.completeSetup);
      final stale = transport.connections.single;
      await runner.connect(_input, sendSetup: transport.completeSetup);
      messages.clear();
      stale.onMessage('stale audio');
      stale.onError(StateError('stale error'));
      stale.onDone();
      transport.connections.last.onMessage('current audio');
      transport.connections.last.onError(StateError('current error'));
      expect(messages, ['current audio']);
      expect(reconnects, 1);
    });

    test('does not reconnect or forward messages when inactive', () async {
      final transport = _FakeGeminiLiveTransport();
      var active = true;
      var reconnects = 0;
      final messages = <dynamic>[];
      final runner = GeminiLiveConnectionRunner(
        transport: transport,
        reconnectCoordinator: GeminiLiveReconnectCoordinator(),
        isActive: () => active,
        onMessage: messages.add,
        onReconnect: () => reconnects++,
      );
      await runner.connect(_input, sendSetup: transport.completeSetup);
      messages.clear();
      active = false;
      transport.connections.single.onMessage('late audio');
      transport.connections.single.onDone();
      expect(reconnects, 0);
      expect(messages, isEmpty);
    });

    for (final hangingTransport in [false, true]) {
      test(
          'deadline includes ${hangingTransport ? 'socket readiness' : 'setup acknowledgement'}',
          () async {
        final ready = Completer<void>();
        final transport = _FakeGeminiLiveTransport(
          ready: hangingTransport ? ready.future : null,
        );
        var sentSetup = false;
        final messages = <dynamic>[];
        final runner = GeminiLiveConnectionRunner(
          transport: transport,
          reconnectCoordinator: GeminiLiveReconnectCoordinator(),
          isActive: () => true,
          onMessage: messages.add,
          onReconnect: () {},
          connectionTimeout: const Duration(milliseconds: 10),
        );
        await expectLater(
          runner.connect(_input, sendSetup: () => sentSetup = true),
          throwsA(isA<TimeoutException>()),
        );
        expect(transport.closeCalls, 1);
        expect(sentSetup, !hangingTransport);
        ready.complete();
        transport.connections.single.onMessage('{"setupComplete":{}}');
        await Future<void>.delayed(Duration.zero);
        expect(messages, isEmpty);
        expect(sentSetup, !hangingTransport);
      });
    }

    test('a reconnect socket closing before setup advances to another attempt',
        () async {
      final transport = _FakeGeminiLiveTransport();
      final coordinator = GeminiLiveReconnectCoordinator();
      final delays = <Duration>[];
      var exhausted = false;
      final connection = GeminiLiveConnectionRunner(
        transport: transport,
        reconnectCoordinator: coordinator,
        isActive: () => true,
        onMessage: (_) => coordinator.markConnected(),
        onReconnect: () {},
      );
      final reconnect = GeminiLiveReconnectRunner(
        coordinator: coordinator,
        isActive: () => true,
        wait: (delay) async => delays.add(delay),
        onConnect: (_) => connection.connect(_input, sendSetup: () {
          if (transport.connections.length == 1) {
            transport.connections.last.onDone();
          } else {
            transport.completeSetup();
          }
        }),
        onExhausted: () => exhausted = true,
      );
      reconnect.attemptReconnect();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(transport.connections, hasLength(2));
      expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
      expect(exhausted, isFalse);
    });
  });
}

class _FakeGeminiLiveTransport implements GeminiLiveTransport {
  _FakeGeminiLiveTransport({this.ready});
  final Future<void>? ready;
  final connections = <_RecordedConnection>[];
  int closeCalls = 0;

  @override
  bool get isConnected => connections.isNotEmpty;

  @override
  Future<void> connect(
    Uri uri, {
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    connections.add(_RecordedConnection(
        uri: uri, onMessage: onMessage, onError: onError, onDone: onDone));
    await ready;
  }

  void completeSetup() => connections.last.onMessage('{"setupComplete":{}}');

  @override
  void send(String data) {}

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

class _RecordedConnection {
  const _RecordedConnection(
      {required this.uri,
      required this.onMessage,
      required this.onError,
      required this.onDone});
  final Uri uri;
  final void Function(dynamic raw) onMessage;
  final void Function(Object error) onError;
  final void Function() onDone;
}

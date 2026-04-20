import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('DefaultGeminiLiveTransport', () {
    test('connect opens a socket and forwards messages', () async {
      Uri? capturedUri;
      final socket = _FakeGeminiLiveSocket();
      final messages = <dynamic>[];
      final transport = DefaultGeminiLiveTransport(
        connector: (uri) {
          capturedUri = uri;
          return socket;
        },
      );

      await transport.connect(
        Uri.parse('wss://example.test/live?access_token=token'),
        onMessage: messages.add,
        onError: (_) {},
        onDone: () {},
      );
      socket.emit('{"setupComplete":{}}');
      await Future<void>.delayed(Duration.zero);

      expect(capturedUri?.host, 'example.test');
      expect(transport.isConnected, isTrue);
      expect(messages.single, '{"setupComplete":{}}');
    });

    test('send writes to the connected socket', () async {
      final socket = _FakeGeminiLiveSocket();
      final transport = DefaultGeminiLiveTransport(connector: (_) => socket);

      await transport.connect(
        Uri.parse('wss://example.test/live'),
        onMessage: (_) {},
        onError: (_) {},
        onDone: () {},
      );
      transport.send('payload');

      expect(socket.sent, ['payload']);
    });

    test('stream error and done callbacks are forwarded', () async {
      final socket = _FakeGeminiLiveSocket();
      final errors = <Object>[];
      var doneCount = 0;
      final transport = DefaultGeminiLiveTransport(connector: (_) => socket);

      await transport.connect(
        Uri.parse('wss://example.test/live'),
        onMessage: (_) {},
        onError: errors.add,
        onDone: () {
          doneCount++;
        },
      );

      socket.emitError(StateError('closed'));
      await socket.finish();
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isA<StateError>());
      expect(doneCount, 1);
      expect(transport.isConnected, isFalse);
    });

    test('close disconnects the active socket', () async {
      final socket = _FakeGeminiLiveSocket();
      final transport = DefaultGeminiLiveTransport(connector: (_) => socket);

      await transport.connect(
        Uri.parse('wss://example.test/live'),
        onMessage: (_) {},
        onError: (_) {},
        onDone: () {},
      );
      await transport.close();

      expect(transport.isConnected, isFalse);
      expect(socket.closed, isTrue);
    });

    test('failed readiness leaves the transport disconnected', () async {
      final socket = _FakeGeminiLiveSocket(
        readyError: StateError('connect failed'),
      );
      final transport = DefaultGeminiLiveTransport(connector: (_) => socket);

      await expectLater(
        transport.connect(
          Uri.parse('wss://example.test/live'),
          onMessage: (_) {},
          onError: (_) {},
          onDone: () {},
        ),
        throwsA(isA<StateError>()),
      );

      expect(transport.isConnected, isFalse);
    });
  });
}

class _FakeGeminiLiveSocket implements GeminiLiveSocket {
  _FakeGeminiLiveSocket({Object? readyError}) : _readyError = readyError;

  final Object? _readyError;
  final _controller = StreamController<dynamic>.broadcast();
  final sent = <String>[];
  bool closed = false;

  @override
  Future<void> get ready async {
    final error = _readyError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void add(String data) {
    sent.add(data);
  }

  void emit(dynamic data) {
    _controller.add(data);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  Future<void> finish() {
    return _controller.close();
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

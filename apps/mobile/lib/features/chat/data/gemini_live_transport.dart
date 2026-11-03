import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web_socket_channel/web_socket_channel.dart';

typedef GeminiLiveSocketConnector = GeminiLiveSocket Function(Uri uri);

abstract interface class GeminiLiveSocket {
  Future<void> get ready;

  Stream<dynamic> get stream;

  void add(String data);

  Future<void> close();
}

class WebSocketGeminiLiveSocket implements GeminiLiveSocket {
  WebSocketGeminiLiveSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void add(String data) {
    _channel.sink.add(data);
  }

  @override
  Future<void> close() {
    return _channel.sink.close();
  }
}

abstract interface class GeminiLiveTransport {
  bool get isConnected;

  Future<void> connect(
    Uri uri, {
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  });

  void send(String data);

  Future<void> close();
}

class DefaultGeminiLiveTransport implements GeminiLiveTransport {
  DefaultGeminiLiveTransport({
    GeminiLiveSocketConnector? connector,
  }) : _connector = connector ??
            ((uri) => WebSocketGeminiLiveSocket(WebSocketChannel.connect(uri)));

  final GeminiLiveSocketConnector _connector;
  GeminiLiveSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  bool _connected = false;
  int _generation = 0;

  @override
  bool get isConnected => _connected && _socket != null;

  @override
  Future<void> connect(
    Uri uri, {
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    final generation = ++_generation;
    await _closeCurrentSocket();
    if (generation != _generation) {
      throw StateError('Connection was cancelled');
    }
    final socket = _connector(uri);
    _socket = socket;

    try {
      await socket.ready;
    } catch (_) {
      if (identical(_socket, socket)) {
        _socket = null;
        _connected = false;
      }
      unawaited(socket.close().catchError((Object error) {
        debugPrint('[GeminiLive] Failed socket cleanup: $error');
      }));
      rethrow;
    }

    if (generation != _generation || !identical(_socket, socket)) {
      throw StateError('Connection was cancelled');
    }
    _connected = true;
    _subscription = socket.stream.listen(
      (dynamic message) {
        if (generation == _generation) onMessage(message);
      },
      onError: (Object error) {
        if (generation == _generation) onError(error);
      },
      onDone: () {
        if (generation != _generation) return;
        if (identical(_socket, socket)) {
          _socket = null;
          _connected = false;
        }
        onDone();
      },
    );
  }

  @override
  void send(String data) {
    _socket?.add(data);
  }

  @override
  Future<void> close() async {
    _generation++;
    await _closeCurrentSocket();
  }

  Future<void> _closeCurrentSocket() async {
    final socket = _socket;
    _socket = null;
    final cancelSubscription = _subscription?.cancel();
    _subscription = null;
    _connected = false;
    await Future.wait<void>([
      if (cancelSubscription != null) cancelSubscription,
      if (socket != null) socket.close(),
    ]);
  }
}

import 'dart:async';

/// Serializes the process-wide PCM plugin without abandoning in-flight native
/// work. A caller can time out, but a later call cannot acquire its output until
/// the native operation actually settles.
class GeminiLiveAudioOutputGate {
  GeminiLiveAudioOutputGate({
    Duration operationTimeout = const Duration(seconds: 8),
  }) : _operationTimeout = operationTimeout;

  final Duration _operationTimeout;
  Future<void>? _pending;
  Object? _owner;
  bool _prepared = false;
  Future<void> Function()? _releaseOwner;

  bool owns(Object owner) => identical(_owner, owner);

  Future<void> prepare(
    Object owner, {
    required Future<void> Function() setup,
    required Future<void> Function() release,
  }) =>
      _exclusive(() async {
        if (owns(owner) && _prepared) return;
        await _releaseCurrent();
        _owner = owner;
        _releaseOwner = release;
        _prepared = false;
        try {
          await setup();
          _prepared = true;
        } catch (_) {
          await _releaseCurrent();
          rethrow;
        }
      });

  Future<void> feed(Object owner, Future<void> Function() action) =>
      _exclusive(() async {
        if (owns(owner) && _prepared) await action();
      });

  Future<void> release(Object owner) => _exclusive(() async {
        if (owns(owner)) await _releaseCurrent();
      });

  Future<void> _releaseCurrent() async {
    final release = _releaseOwner;
    if (release == null) return;
    await release();
    _owner = null;
    _releaseOwner = null;
    _prepared = false;
  }

  Future<void> _exclusive(Future<void> Function() action) async {
    final elapsed = Stopwatch()..start();
    Duration remaining() {
      final duration = _operationTimeout - elapsed.elapsed;
      if (duration <= Duration.zero) {
        throw TimeoutException('PCM output is busy');
      }
      return duration;
    }

    // Waiters have a deadline and are not appended to an unbounded native queue.
    // Claim the slot synchronously after the previous operation has settled.
    while (_pending != null) {
      await _pending!.timeout(remaining());
    }
    final deadline = remaining();
    final operation = Future<void>.sync(action);
    final settled = operation.then<void>((_) {}, onError: (Object _) {});
    _pending = settled;
    unawaited(settled.then((_) {
      if (identical(_pending, settled)) _pending = null;
    }));
    await operation.timeout(deadline);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_runner.dart';

void main() {
  group('GeminiLiveReconnectRunner', () {
    test('attemptReconnect waits and reconnects with the resumption handle',
        () async {
      final coordinator = GeminiLiveReconnectCoordinator()
        ..updateResumptionHandle('handle-1');
      final delays = <Duration>[];
      final handles = <String?>[];
      final runner = GeminiLiveReconnectRunner(
        coordinator: coordinator,
        isActive: () => true,
        wait: (delay) async {
          delays.add(delay);
        },
        onConnect: (handle) async {
          handles.add(handle);
        },
        onExhausted: () {},
      );

      runner.attemptReconnect();
      await _pumpAsync();

      expect(delays, [const Duration(seconds: 1)]);
      expect(handles, ['handle-1']);
    });

    test('attemptReconnect ignores duplicate reconnect requests', () async {
      final coordinator = GeminiLiveReconnectCoordinator();
      var connectCalls = 0;
      final runner = GeminiLiveReconnectRunner(
        coordinator: coordinator,
        isActive: () => true,
        wait: (_) async {},
        onConnect: (_) async {
          connectCalls++;
        },
        onExhausted: () {},
      );

      runner.attemptReconnect();
      runner.attemptReconnect();
      await _pumpAsync();

      expect(connectCalls, 1);
    });

    test('attemptReconnect reports exhausted reconnect attempts', () {
      final coordinator = GeminiLiveReconnectCoordinator(
        maxReconnectAttempts: 0,
      );
      var exhausted = false;
      final runner = GeminiLiveReconnectRunner(
        coordinator: coordinator,
        isActive: () => true,
        onConnect: (_) async {},
        onExhausted: () {
          exhausted = true;
        },
      );

      runner.attemptReconnect();

      expect(exhausted, isTrue);
    });

    test('failed reconnect marks idle and schedules the next attempt',
        () async {
      final coordinator = GeminiLiveReconnectCoordinator();
      final delays = <Duration>[];
      var connectCalls = 0;
      final runner = GeminiLiveReconnectRunner(
        coordinator: coordinator,
        isActive: () => true,
        wait: (delay) async {
          delays.add(delay);
        },
        onConnect: (_) async {
          connectCalls++;
          if (connectCalls == 1) {
            throw StateError('temporary failure');
          }
        },
        onExhausted: () {},
      );

      runner.attemptReconnect();
      await _pumpAsync();
      await _pumpAsync();

      expect(connectCalls, 2);
      expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    });
  });
}

Future<void> _pumpAsync() async {
  await Future<void>.delayed(Duration.zero);
}

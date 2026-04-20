import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';

void main() {
  group('GeminiLiveReconnectCoordinator', () {
    test('beginConnection tracks the current connection generation', () {
      final coordinator = GeminiLiveReconnectCoordinator();

      final first = coordinator.beginConnection();
      final second = coordinator.beginConnection();

      expect(coordinator.isCurrentConnection(first), isFalse);
      expect(coordinator.isCurrentConnection(second), isTrue);
    });

    test('requestReconnect schedules exponential backoff attempts', () {
      final coordinator = GeminiLiveReconnectCoordinator();

      final first = coordinator.requestReconnect();
      coordinator.markReconnectIdle();
      final second = coordinator.requestReconnect();
      coordinator.markReconnectIdle();
      final third = coordinator.requestReconnect();

      expect(first.status, GeminiLiveReconnectDecisionStatus.scheduled);
      expect(first.delay, const Duration(seconds: 1));
      expect(first.attempt, 1);
      expect(second.delay, const Duration(seconds: 2));
      expect(second.attempt, 2);
      expect(third.delay, const Duration(seconds: 4));
      expect(third.attempt, 3);
    });

    test('requestReconnect prevents duplicate in-flight reconnects', () {
      final coordinator = GeminiLiveReconnectCoordinator();

      final first = coordinator.requestReconnect();
      final duplicate = coordinator.requestReconnect();

      expect(first.status, GeminiLiveReconnectDecisionStatus.scheduled);
      expect(
        duplicate.status,
        GeminiLiveReconnectDecisionStatus.alreadyInProgress,
      );
    });

    test('requestReconnect reports exhausted after the max attempts', () {
      final coordinator = GeminiLiveReconnectCoordinator(
        maxReconnectAttempts: 2,
      );

      coordinator.requestReconnect();
      coordinator.markReconnectIdle();
      coordinator.requestReconnect();
      coordinator.markReconnectIdle();
      final exhausted = coordinator.requestReconnect();

      expect(exhausted.status, GeminiLiveReconnectDecisionStatus.exhausted);
    });

    test('markConnected resets attempts and reconnecting state', () {
      final coordinator = GeminiLiveReconnectCoordinator();

      coordinator.requestReconnect();
      coordinator.markConnected();
      final next = coordinator.requestReconnect();

      expect(next.status, GeminiLiveReconnectDecisionStatus.scheduled);
      expect(next.delay, const Duration(seconds: 1));
      expect(next.attempt, 1);
    });

    test('updateResumptionHandle stores the latest session handle', () {
      final coordinator = GeminiLiveReconnectCoordinator();

      coordinator.updateResumptionHandle('handle-1');
      coordinator.updateResumptionHandle('handle-2');

      expect(coordinator.resumptionHandle, 'handle-2');
    });
  });
}

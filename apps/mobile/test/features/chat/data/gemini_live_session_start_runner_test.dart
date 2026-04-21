import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_start_runner.dart';

void main() {
  group('GeminiLiveSessionStartRunner', () {
    test('reports model validation errors without connecting', () async {
      var connectCalls = 0;
      final states = <String>[];
      final errors = <String>[];
      final runner = _buildRunner(
        connect: () async {
          connectCalls++;
        },
        states: states,
        errors: errors,
      );

      await runner.start(model: '');

      expect(connectCalls, 0);
      expect(errors, ['음성 모델이 설정되지 않았습니다']);
      expect(states, ['error']);
    });

    test('marks the lifecycle active, resets reconnect, and connects',
        () async {
      final lifecycle = GeminiLiveLifecycleController()..markEnding();
      final reconnect = GeminiLiveReconnectCoordinator();
      reconnect.requestReconnect();
      var connectCalls = 0;
      final states = <String>[];
      final runner = _buildRunner(
        lifecycleController: lifecycle,
        reconnectCoordinator: reconnect,
        connect: () async {
          connectCalls++;
        },
        states: states,
      );

      await runner.start(model: 'gemini-live');

      expect(lifecycle.isActive, isTrue);
      expect(connectCalls, 1);
      expect(states, ['connecting']);
      expect(
        reconnect.requestReconnect().status,
        GeminiLiveReconnectDecisionStatus.scheduled,
      );
    });

    test('emits a user-facing error when connect fails', () async {
      final states = <String>[];
      final errors = <String>[];
      final runner = _buildRunner(
        connect: () => throw StateError('boom'),
        states: states,
        errors: errors,
      );

      await runner.start(model: 'gemini-live');

      expect(errors, ['연결에 실패했습니다']);
      expect(states, ['connecting', 'error']);
    });
  });
}

GeminiLiveSessionStartRunner _buildRunner({
  GeminiLiveLifecycleController? lifecycleController,
  GeminiLiveReconnectCoordinator? reconnectCoordinator,
  Future<void> Function()? connect,
  List<String>? states,
  List<String>? errors,
}) {
  final stateEvents = states ?? <String>[];
  final errorEvents = errors ?? <String>[];
  return GeminiLiveSessionStartRunner(
    lifecycleController: lifecycleController ?? GeminiLiveLifecycleController(),
    reconnectCoordinator:
        reconnectCoordinator ?? GeminiLiveReconnectCoordinator(),
    connect: connect ?? () async {},
    emitConnectingState: () => stateEvents.add('connecting'),
    emitErrorState: () => stateEvents.add('error'),
    emitError: errorEvents.add,
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_live_session_starter.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_start_coordinator.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_state.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_start_flow_coordinator.dart';

void main() {
  group('VoiceCallSessionStartCoordinator', () {
    test('prepares start flow and starts live session with active guard',
        () async {
      final service = _FakeGeminiLiveService();
      final prepareInputs = <VoiceCallStartFlowInput>[];
      final liveInputs = <VoiceCallLiveSessionStartInput>[];
      var stale = false;
      var state = const VoiceCallSessionState();
      final coordinator = VoiceCallSessionStartCoordinator(
        prepareStartFlow: (input) async {
          prepareInputs.add(input);
          return VoiceCallStartFlowResult.ready(service);
        },
        startLiveSession: (input) async {
          liveInputs.add(input);
          return const VoiceCallLiveSessionStartResult.success();
        },
      );

      await coordinator.start(
        _input(
          isStale: () => stale,
          getState: () => state,
          setState: (nextState) => state = nextState,
        ),
      );

      expect(prepareInputs.single.request.characterId, 'char-1');
      expect(liveInputs.single.service, service);
      expect(liveInputs.single.isActive(), isTrue);

      stale = true;

      expect(liveInputs.single.isActive(), isFalse);
    });

    test('maps start flow failure to error state and skips live start',
        () async {
      var liveStartCalls = 0;
      var state = const VoiceCallSessionState(
        status: VoiceCallStatus.connecting,
      );
      final coordinator = VoiceCallSessionStartCoordinator(
        prepareStartFlow: (_) async {
          return const VoiceCallStartFlowResult.failure('bootstrap failed');
        },
        startLiveSession: (_) async {
          liveStartCalls++;
          return const VoiceCallLiveSessionStartResult.success();
        },
      );

      await coordinator.start(
        _input(
          getState: () => state,
          setState: (nextState) => state = nextState,
        ),
      );

      expect(liveStartCalls, 0);
      expect(state.status, VoiceCallStatus.error);
      expect(state.errorMessage, 'bootstrap failed');
    });

    test('preserves non-retryable start flow failures', () async {
      var state = const VoiceCallSessionState(
        status: VoiceCallStatus.connecting,
      );
      final coordinator = VoiceCallSessionStartCoordinator(
        prepareStartFlow: (_) async {
          return const VoiceCallStartFlowResult.failure(
            '오늘의 AI 통화 횟수를 초과했습니다.',
            canRetry: false,
          );
        },
        startLiveSession: (_) async {
          return const VoiceCallLiveSessionStartResult.success();
        },
      );

      await coordinator.start(
        _input(
          getState: () => state,
          setState: (nextState) => state = nextState,
        ),
      );

      expect(state.status, VoiceCallStatus.error);
      expect(state.errorMessage, '오늘의 AI 통화 횟수를 초과했습니다.');
      expect(state.canRetry, isFalse);
    });

    test('maps live session failure to error state', () async {
      var state = const VoiceCallSessionState(
        status: VoiceCallStatus.connecting,
      );
      final coordinator = VoiceCallSessionStartCoordinator(
        prepareStartFlow: (_) async {
          return VoiceCallStartFlowResult.ready(_FakeGeminiLiveService());
        },
        startLiveSession: (_) async {
          return const VoiceCallLiveSessionStartResult.failure('live failed');
        },
      );

      await coordinator.start(
        _input(
          getState: () => state,
          setState: (nextState) => state = nextState,
        ),
      );

      expect(state.status, VoiceCallStatus.error);
      expect(state.errorMessage, 'live failed');
    });

    test('does not start live session when start flow becomes stale', () async {
      var liveStartCalls = 0;
      var state = const VoiceCallSessionState(
        status: VoiceCallStatus.connected,
      );
      final coordinator = VoiceCallSessionStartCoordinator(
        prepareStartFlow: (_) async {
          return const VoiceCallStartFlowResult.stale();
        },
        startLiveSession: (_) async {
          liveStartCalls++;
          return const VoiceCallLiveSessionStartResult.success();
        },
      );

      await coordinator.start(
        _input(
          getState: () => state,
          setState: (nextState) => state = nextState,
        ),
      );

      expect(liveStartCalls, 0);
      expect(state.status, VoiceCallStatus.connected);
    });
  });
}

VoiceCallSessionStartInput _input({
  VoiceCallSessionStaleCheck? isStale,
  required VoiceCallSessionStartStateReader getState,
  required VoiceCallSessionStartStateWriter setState,
}) {
  return VoiceCallSessionStartInput(
    request: const VoiceCallSessionRequest(characterId: 'char-1'),
    resources: null,
    isStale: isStale ?? () => false,
    getState: getState,
    setState: setState,
    callbacks: VoiceCallLiveSessionCallbacks(
      onStateChange: (_) {},
      onAiTextDelta: (_) {},
      onTranscriptEntry: (_) {},
      onError: (_) {},
    ),
  );
}

class _FakeGeminiLiveService extends GeminiLiveService {
  _FakeGeminiLiveService()
      : super(
          wsUri: 'wss://example.com/live',
          token: 'token',
          model: 'gemini-live',
        );
}

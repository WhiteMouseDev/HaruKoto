import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_bootstrap_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_resources.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_state.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_start_context_reader.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_start_flow_coordinator.dart';

void main() {
  group('VoiceCallStartFlowCoordinator', () {
    test('cancels old session, applies connecting state, and prepares service',
        () async {
      final service = _FakeGeminiLiveService();
      final connection = _FakeVoiceCallConnectionService(service: service);
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final states = <VoiceCallSessionState>[];
      final resources = VoiceCallSessionResources(ringtone);
      final coordinator = VoiceCallStartFlowCoordinator(
        startContextReader: _FakeVoiceCallStartContextReader(
          const VoiceCallStartContext(
            callSettings: CallSettings(subtitleEnabled: false),
            userNickname: 'Tester',
            jlptLevel: 'N4',
          ),
        ),
        connectionService: connection,
      );

      final result = await coordinator.prepare(
        VoiceCallStartFlowInput(
          request: const VoiceCallSessionRequest(characterId: 'char-1'),
          resources: resources,
          isStale: () => false,
          setState: states.add,
        ),
      );

      expect(result.service, service);
      expect(result.stale, isFalse);
      expect(result.hasError, isFalse);
      expect(ringtone.stopCalls, 1);
      expect(ringtone.startCalls, 1);
      expect(connection.prepareCalls, 1);
      expect(connection.lastInput?.userNickname, 'Tester');
      expect(connection.lastInput?.jlptLevel, 'N4');
      expect(states.single.status, VoiceCallStatus.connecting);
      expect(states.single.showSubtitle, isFalse);
    });

    test('returns failure and stops ringtone when connection prepare fails',
        () async {
      final connection = _FakeVoiceCallConnectionService(
        errorMessage: '연결에 실패했습니다',
      );
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final coordinator = VoiceCallStartFlowCoordinator(
        startContextReader: _FakeVoiceCallStartContextReader(
          const VoiceCallStartContext(
            callSettings: CallSettings(),
            userNickname: 'Tester',
            jlptLevel: 'N5',
          ),
        ),
        connectionService: connection,
      );

      final result = await coordinator.prepare(
        VoiceCallStartFlowInput(
          request: const VoiceCallSessionRequest(characterId: 'char-1'),
          resources: VoiceCallSessionResources(ringtone),
          isStale: () => false,
          setState: (_) {},
        ),
      );

      expect(result.hasError, isTrue);
      expect(result.errorMessage, '연결에 실패했습니다');
      expect(result.stale, isFalse);
      expect(ringtone.startCalls, 1);
      expect(ringtone.stopCalls, 2);
    });

    test('disposes prepared service when generation becomes stale', () async {
      final service = _FakeGeminiLiveService();
      final connection = _FakeVoiceCallConnectionService(service: service);
      var staleChecks = 0;
      final coordinator = VoiceCallStartFlowCoordinator(
        startContextReader: _FakeVoiceCallStartContextReader(
          const VoiceCallStartContext(
            callSettings: CallSettings(),
            userNickname: 'Tester',
            jlptLevel: 'N5',
          ),
        ),
        connectionService: connection,
      );

      final result = await coordinator.prepare(
        VoiceCallStartFlowInput(
          request: const VoiceCallSessionRequest(characterId: 'char-1'),
          resources: VoiceCallSessionResources(_FakeVoiceCallRingtonePlayer()),
          isStale: () {
            staleChecks++;
            return staleChecks >= 3;
          },
          setState: (_) {},
        ),
      );

      expect(result.stale, isTrue);
      expect(result.service, isNull);
      expect(service.disposeCalls, 1);
    });
  });
}

class _FakeVoiceCallStartContextReader extends VoiceCallStartContextReader {
  _FakeVoiceCallStartContextReader(this._context)
      : super(
          readPreferences: () => throw UnimplementedError(),
          readProfile: () => throw UnimplementedError(),
        );

  final VoiceCallStartContext _context;

  @override
  VoiceCallStartContext read() => _context;
}

class _FakeVoiceCallConnectionService extends VoiceCallConnectionService {
  _FakeVoiceCallConnectionService({
    _FakeGeminiLiveService? service,
    this.errorMessage,
  })  : service = service ?? _FakeGeminiLiveService(),
        super(
          bootstrapService: _UnusedVoiceCallBootstrapService(),
          liveServiceFactory: (_, __) => service ?? _FakeGeminiLiveService(),
        );

  final _FakeGeminiLiveService service;
  final String? errorMessage;
  int prepareCalls = 0;
  VoiceCallConnectionInput? lastInput;

  @override
  Future<GeminiLiveService> prepare(VoiceCallConnectionInput input) async {
    prepareCalls++;
    lastInput = input;
    final message = errorMessage;
    if (message != null) {
      throw VoiceCallConnectionException(message);
    }
    return service;
  }
}

class _FakeGeminiLiveService extends GeminiLiveService {
  _FakeGeminiLiveService()
      : super(
          wsUri: 'wss://example.com/live',
          token: 'token',
          model: 'gemini-live',
        );

  int disposeCalls = 0;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _FakeVoiceCallRingtonePlayer implements VoiceCallRingtonePlayer {
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> startLoop() async {
    startCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {}
}

class _UnusedVoiceCallBootstrapService extends VoiceCallBootstrapService {
  _UnusedVoiceCallBootstrapService() : super(_UnusedChatRepository());
}

class _UnusedChatRepository extends ChatRepository {}

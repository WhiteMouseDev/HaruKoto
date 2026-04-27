import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_bootstrap_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_resources.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_start_connection_step.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_start_context_reader.dart';

void main() {
  group('VoiceCallStartConnectionStep', () {
    test('prepares live service from start context', () async {
      final service = _FakeGeminiLiveService();
      final connection = _FakeVoiceCallConnectionService(service: service);
      final step = VoiceCallStartConnectionStep(connectionService: connection);

      final result = await step.connect(
        VoiceCallStartConnectionInput(
          request: const VoiceCallSessionRequest(characterId: 'char-1'),
          startContext: _startContext(),
          resources: VoiceCallSessionResources(_FakeVoiceCallRingtonePlayer()),
          isStale: () => false,
        ),
      );

      expect(result.service, service);
      expect(result.stale, isFalse);
      expect(result.errorMessage, isNull);
      expect(connection.lastInput?.userNickname, 'Tester');
      expect(connection.lastInput?.jlptLevel, 'N4');
    });

    test('disposes prepared service when generation becomes stale', () async {
      final service = _FakeGeminiLiveService();
      final connection = _FakeVoiceCallConnectionService(service: service);
      final step = VoiceCallStartConnectionStep(connectionService: connection);

      final result = await step.connect(
        VoiceCallStartConnectionInput(
          request: const VoiceCallSessionRequest(characterId: 'char-1'),
          startContext: _startContext(),
          resources: VoiceCallSessionResources(_FakeVoiceCallRingtonePlayer()),
          isStale: () => true,
        ),
      );

      expect(result.stale, isTrue);
      expect(service.disposeCalls, 1);
    });

    test('returns user-facing failure and stops ringtone on connection error',
        () async {
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final connection = _FakeVoiceCallConnectionService(
        errorMessage: '연결에 실패했습니다',
      );
      final step = VoiceCallStartConnectionStep(connectionService: connection);

      final result = await step.connect(
        VoiceCallStartConnectionInput(
          request: const VoiceCallSessionRequest(characterId: 'char-1'),
          startContext: _startContext(),
          resources: VoiceCallSessionResources(ringtone),
          isStale: () => false,
        ),
      );

      expect(result.errorMessage, '연결에 실패했습니다');
      expect(ringtone.stopCalls, 1);
    });

    test('maps unexpected errors to connection failure and stops ringtone',
        () async {
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final connection = _FakeVoiceCallConnectionService(
        unexpectedError: StateError('boom'),
      );
      final step = VoiceCallStartConnectionStep(connectionService: connection);

      final result = await step.connect(
        VoiceCallStartConnectionInput(
          request: const VoiceCallSessionRequest(characterId: 'char-1'),
          startContext: _startContext(),
          resources: VoiceCallSessionResources(ringtone),
          isStale: () => false,
        ),
      );

      expect(result.errorMessage, contains('연결에 실패했습니다'));
      expect(ringtone.stopCalls, 1);
    });

    test(
      'maps rate-limited API errors to non-retryable quota failure',
      () async {
        final ringtone = _FakeVoiceCallRingtonePlayer();
        final connection = _FakeVoiceCallConnectionService(
          unexpectedError: DioException(
            requestOptions: RequestOptions(path: '/chat/live-token'),
            error: const ApiException(
              message: '오늘의 AI 통화 횟수를 초과했습니다.',
              statusCode: 429,
              errorCode: 'RATE_LIMITED',
            ),
          ),
        );
        final step =
            VoiceCallStartConnectionStep(connectionService: connection);

        final result = await step.connect(
          VoiceCallStartConnectionInput(
            request: const VoiceCallSessionRequest(characterId: 'char-1'),
            startContext: _startContext(),
            resources: VoiceCallSessionResources(ringtone),
            isStale: () => false,
          ),
        );

        expect(result.errorMessage, '오늘의 AI 통화 횟수를 초과했습니다.');
        expect(result.errorMessage, isNot(contains('DioException')));
        expect(result.canRetry, isFalse);
        expect(ringtone.stopCalls, 1);
      },
    );
  });
}

VoiceCallStartContext _startContext() {
  return const VoiceCallStartContext(
    callSettings: CallSettings(),
    userNickname: 'Tester',
    jlptLevel: 'N4',
  );
}

class _FakeVoiceCallConnectionService extends VoiceCallConnectionService {
  _FakeVoiceCallConnectionService({
    _FakeGeminiLiveService? service,
    this.errorMessage,
    this.unexpectedError,
  })  : service = service ?? _FakeGeminiLiveService(),
        super(
          bootstrapService: _UnusedVoiceCallBootstrapService(),
          liveServiceFactory: (_, __) => service ?? _FakeGeminiLiveService(),
        );

  final _FakeGeminiLiveService service;
  final String? errorMessage;
  final Object? unexpectedError;
  VoiceCallConnectionInput? lastInput;

  @override
  Future<GeminiLiveService> prepare(VoiceCallConnectionInput input) async {
    lastInput = input;
    final error = unexpectedError;
    if (error != null) throw error;
    final message = errorMessage;
    if (message != null) throw VoiceCallConnectionException(message);
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
  int stopCalls = 0;

  @override
  Future<void> startLoop() async {}

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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_bootstrap_service.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_character_voice_context_loader.dart';

void main() {
  group('VoiceCallBootstrapService', () {
    test(
        'late cancelled preparation closes only its own id without requesting a token',
        () async {
      final repository = _FakeChatRepository();
      final release = Completer<void>();
      repository.createBlocker = release.future;
      var cancelled = false;
      final pending =
          VoiceCallBootstrapService(repository).prepare(VoiceCallBootstrapInput(
        characterId: null,
        conversationId: 'cancelled-id',
        isCancelled: () => cancelled,
        callSettings: const CallSettings(),
        userNickname: 'Tester',
        jlptLevel: 'N5',
      ));
      cancelled = true;
      release.complete();
      await expectLater(pending, throwsA(isA<Exception>()));
      expect(repository.events,
          ['prepare:cancelled-id:null', 'close:cancelled-id:false:0']);
    });

    test('prepares the same stable id before requesting a scenario token',
        () async {
      final repository = _FakeChatRepository(
          scenarioInstruction: 'hotel', scenarioGreeting: 'welcome');
      final events = <String>[];
      repository.events = events;
      await VoiceCallBootstrapService(repository)
          .prepare(VoiceCallBootstrapInput(
        characterId: null,
        scenarioId: 'hotel-1',
        conversationId: 'stable-id',
        onSessionPrepared: (id) => events.add('confirmed:$id'),
        callSettings: const CallSettings(),
        userNickname: 'Tester',
        jlptLevel: 'N5',
      ));
      expect(events, [
        'prepare:stable-id:hotel-1',
        'confirmed:stable-id',
        'token:stable-id'
      ]);
    });

    test(
        'uses server scenario prompt and greeting instead of the friend persona',
        () async {
      final repository = _FakeChatRepository(
        scenarioInstruction: 'ホテルの受付として予約名を確認してください。',
        scenarioGreeting: '受付の挨拶から始めてください。',
      );
      final bootstrap = await VoiceCallBootstrapService(
        repository,
        characterContextLoader: _FakeCharacterVoiceContextLoader(),
      ).prepare(const VoiceCallBootstrapInput(
        characterId: null,
        scenarioId: 'hotel-1',
        callSettings: CallSettings(),
        userNickname: 'Tester',
        jlptLevel: 'N5',
      ));
      expect(repository.lastTokenScenarioId, 'hotel-1');
      expect(bootstrap.systemInstruction, 'ホテルの受付として予約名を確認してください。');
      expect(bootstrap.scenarioGreeting, '受付の挨拶から始めてください。');
    });

    test('does not silently start a friend call when scenario setup is absent',
        () async {
      final service = VoiceCallBootstrapService(_FakeChatRepository());
      await expectLater(
          service.prepare(const VoiceCallBootstrapInput(
            characterId: null,
            scenarioId: 'hotel-1',
            callSettings: CallSettings(),
            userNickname: 'Tester',
            jlptLevel: 'N5',
          )),
          throwsA(isA<Exception>()));
    });

    test('combines live token, user context, and character voice context',
        () async {
      final repository = _FakeChatRepository();
      final service = VoiceCallBootstrapService(
        repository,
        characterContextLoader: _FakeCharacterVoiceContextLoader(),
      );

      final bootstrap = await service.prepare(
        const VoiceCallBootstrapInput(
          characterId: 'char-1',
          callSettings: CallSettings(
            silenceDurationMs: 1500,
            subtitleEnabled: false,
          ),
          userNickname: 'Tester',
          jlptLevel: 'N4',
        ),
      );

      expect(repository.lastTokenCharacterId, 'char-1');
      expect(bootstrap.wsUri, 'wss://example.test/live');
      expect(bootstrap.token, 'token');
      expect(bootstrap.model, 'gemini-live');
      expect(bootstrap.voiceName, 'Kore');
      expect(bootstrap.systemInstruction, 'friendly');
      expect(bootstrap.userNickname, 'TokenUser');
      expect(bootstrap.jlptLevel, 'N3');
      expect(bootstrap.silenceDurationMs, 1500);
      expect(bootstrap.subtitleEnabled, isFalse);
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository({this.scenarioInstruction, this.scenarioGreeting});
  final String? scenarioInstruction;
  final String? scenarioGreeting;
  String? lastTokenCharacterId;
  String? lastTokenScenarioId;
  List<String> events = [];
  Future<void>? createBlocker;
  @override
  Future<void> createLiveSession(
      {required String conversationId,
      String? scenarioId,
      String? characterId}) async {
    events.add('prepare:$conversationId:$scenarioId');
    await createBlocker;
  }

  @override
  Future<LiveFeedbackResponse> sendLiveFeedback(
      {required List<Map<String, String>> transcript,
      required int durationSeconds,
      bool analysisEnabled = true,
      String? conversationId,
      String? scenarioId,
      String? characterId}) async {
    events.add('close:$conversationId:$analysisEnabled:$durationSeconds');
    return LiveFeedbackResponse(
        conversationId: conversationId!, xpEarned: 0, events: const []);
  }

  @override
  Future<LiveTokenResponse> fetchLiveToken(
      {String? characterId, String? scenarioId, String? conversationId}) async {
    events.add('token:$conversationId');
    lastTokenCharacterId = characterId;
    lastTokenScenarioId = scenarioId;
    return LiveTokenResponse(
      wsUri: 'wss://example.test/live',
      token: 'token',
      model: 'gemini-live',
      userNickname: 'TokenUser',
      jlptLevel: 'N3',
      systemInstruction: scenarioInstruction,
      scenarioGreeting: scenarioGreeting,
    );
  }
}

class _FakeCharacterVoiceContextLoader
    extends VoiceCallCharacterVoiceContextLoader {
  _FakeCharacterVoiceContextLoader() : super(_UnusedChatRepository());

  @override
  Future<VoiceCallCharacterVoiceContext> load(String? characterId) async {
    return const VoiceCallCharacterVoiceContext(
      voiceName: 'Kore',
      systemInstruction: 'friendly',
    );
  }
}

class _UnusedChatRepository extends ChatRepository {}

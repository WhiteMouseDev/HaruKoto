import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_resources.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_state.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_start_context_reader.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_start_preparation_step.dart';

void main() {
  group('VoiceCallStartPreparationStep', () {
    test('cancels old session, applies connecting state, and starts ringtone',
        () async {
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final states = <VoiceCallSessionState>[];
      const context = VoiceCallStartContext(
        callSettings: CallSettings(subtitleEnabled: false),
        userNickname: 'Tester',
        jlptLevel: 'N4',
      );
      final step = VoiceCallStartPreparationStep(
        startContextReader: _FakeVoiceCallStartContextReader(context),
      );

      final result = await step.prepare(
        VoiceCallStartPreparationInput(
          resources: VoiceCallSessionResources(ringtone),
          isStale: () => false,
          setState: states.add,
        ),
      );

      expect(result.stale, isFalse);
      expect(result.context, same(context));
      expect(ringtone.stopCalls, 1);
      expect(ringtone.startCalls, 1);
      expect(states.single.status, VoiceCallStatus.connecting);
      expect(states.single.showSubtitle, isFalse);
    });

    test('returns stale after cancel without reading context', () async {
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final reader = _FakeVoiceCallStartContextReader(
        const VoiceCallStartContext(
          callSettings: CallSettings(),
          userNickname: 'Tester',
          jlptLevel: 'N5',
        ),
      );
      final step = VoiceCallStartPreparationStep(startContextReader: reader);

      final result = await step.prepare(
        VoiceCallStartPreparationInput(
          resources: VoiceCallSessionResources(ringtone),
          isStale: () => true,
          setState: (_) {},
        ),
      );

      expect(result.stale, isTrue);
      expect(reader.readCalls, 0);
      expect(ringtone.stopCalls, 1);
      expect(ringtone.startCalls, 0);
    });

    test('returns stale after ringtone when generation changes', () async {
      final ringtone = _FakeVoiceCallRingtonePlayer();
      var staleChecks = 0;
      final step = VoiceCallStartPreparationStep(
        startContextReader: _FakeVoiceCallStartContextReader(
          const VoiceCallStartContext(
            callSettings: CallSettings(),
            userNickname: 'Tester',
            jlptLevel: 'N5',
          ),
        ),
      );

      final result = await step.prepare(
        VoiceCallStartPreparationInput(
          resources: VoiceCallSessionResources(ringtone),
          isStale: () {
            staleChecks++;
            return staleChecks >= 2;
          },
          setState: (_) {},
        ),
      );

      expect(result.stale, isTrue);
      expect(ringtone.stopCalls, 1);
      expect(ringtone.startCalls, 1);
    });
  });
}

class _FakeVoiceCallStartContextReader extends VoiceCallStartContextReader {
  _FakeVoiceCallStartContextReader(this._context)
      : super(
          readPreferences: () => throw UnimplementedError(),
          readProfile: () => throw UnimplementedError(),
          readProfileFuture: () => throw UnimplementedError(),
        );

  final VoiceCallStartContext _context;
  int readCalls = 0;

  @override
  Future<VoiceCallStartContext> read() async {
    readCalls++;
    return _context;
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/presentation/voice_call_page.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_end_call_handler.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_end_flow_coordinator.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_live_session_starter.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_start_coordinator.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_start_flow_coordinator.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  group('VoiceCallPage', () {
    testWidgets('shows no-data feedback when a short call has no transcript',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceCallSessionStartCoordinatorProvider.overrideWith(
              (ref) => VoiceCallSessionStartCoordinator(
                prepareStartFlow: (_) async =>
                    const VoiceCallStartFlowResult.stale(),
                startLiveSession: (_) async =>
                    const VoiceCallLiveSessionStartResult.stale(),
              ),
            ),
            voiceCallEndCallHandlerProvider.overrideWith(
              (ref) => VoiceCallEndCallHandler(
                endFlow: (_) async {
                  return const VoiceCallEndFlowResult(
                    feedbackError: 'no_transcript',
                  );
                },
              ),
            ),
          ],
          child: const MaterialApp(home: VoiceCallPage(characterName: '하루')),
        ),
      );

      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.phoneOff));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('회화 리포트'), findsOneWidget);
      expect(find.text('대화가 너무 짧아요'), findsOneWidget);
      expect(find.textContaining('분석할 내용이 충분하지 않아'), findsOneWidget);
      expect(find.text('다시 통화하기'), findsOneWidget);

      await tester.tap(find.text('다시 통화하기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('회화 리포트'), findsNothing);
      expect(find.text('하루'), findsOneWidget);
      expect(find.byIcon(LucideIcons.phoneOff), findsOneWidget);
    });
  });
}

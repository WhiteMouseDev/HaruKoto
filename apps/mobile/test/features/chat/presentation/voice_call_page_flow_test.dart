import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/presentation/voice_call_page.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';

void main() {
  testWidgets('foreground recovery is explicit after app interruption at 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final controller = _HelpController(true);
    await tester.pumpWidget(ProviderScope(
      overrides: [voiceCallSessionProvider.overrideWith(() => controller)],
      child: const MaterialApp(home: VoiceCallPage(characterName: '친구')),
    ));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('마이크 일시중지'), findsOneWidget);
    expect(find.text('연결됨 · 마이크 켜짐'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, '마이크 다시 연결'))
            .onPressed,
        isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.resumeCalls, 0);
    expect(find.text('마이크 다시 연결'), findsOneWidget);
    await tester.tap(find.text('마이크 다시 연결'));
    await tester.pump();
    expect(controller.resumeCalls, 1);
    expect(controller.state.isMuted, isTrue);
    expect(find.text('마이크 꺼짐'), findsOneWidget);
    expect(find.text('마이크 다시 연결'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final initiallyMuted in [true, false]) {
    testWidgets(
        'help temporarily mutes then restores prior state ($initiallyMuted) at 320px',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = _HelpController(initiallyMuted);
        await tester.pumpWidget(ProviderScope(
            overrides: [
              voiceCallSessionProvider.overrideWith(() => controller)
            ],
            child: const MaterialApp(
                home:
                    VoiceCallPage(scenarioId: 'hotel', characterName: '친구'))));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        for (final label in [
          if (initiallyMuted) '음소거 해제' else '음소거',
          '도움',
          '통화 종료',
          '자막'
        ]) {
          final finder = find.bySemanticsLabel(label);
          expect(finder, findsOneWidget);
          final data = tester.getSemantics(finder).getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.flagsCollection.isEnabled, isNot(Tristate.none));
          expect(data.flagsCollection.isEnabled, Tristate.isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
        }
        // The label itself is part of the button's pointer target.
        await tester.tap(find.text('도움'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.state.isMuted, isTrue);
        expect(find.text('답변 힌트 알려줘'), findsOneWidget);
        await tester.ensureVisible(find.text('다시 말해줘'));
        await tester.tap(find.text('다시 말해줘'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.state.isMuted, initiallyMuted);
        expect(controller.action, GeminiLiveHelpAction.repeat);
        expect(controller.targetText, 'お名前を教えてください。');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('도움'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.ensureVisible(find.text('대화로 돌아가기'));
        await tester.tap(find.text('대화로 돌아가기'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(controller.state.isMuted, initiallyMuted);
        controller.enterEnding();
        await tester.pump();
        final ended = tester
            .getSemantics(find.bySemanticsLabel('통화 종료'))
            .getSemanticsData();
        expect(ended.flagsCollection.isButton, isTrue);
        expect(ended.flagsCollection.isEnabled, isNot(Tristate.none));
        expect(ended.flagsCollection.isEnabled, Tristate.isFalse);
        expect(ended.hasAction(SemanticsAction.tap), isFalse);
        await tester.tap(find.text('통화 종료'));
        expect(controller.endCalls, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        semantics.dispose();
      }
    });
  }
}

class _HelpController extends VoiceCallSessionController {
  _HelpController(this.muted);
  final bool muted;
  GeminiLiveHelpAction? action;
  String? targetText;
  int endCalls = 0;
  int resumeCalls = 0;
  void enterEnding() {
    state = state.copyWith(status: VoiceCallStatus.ending);
  }

  @override
  Future<VoiceCallEndResult> endCall() async {
    endCalls++;
    return const VoiceCallEndResult(ignored: true);
  }

  @override
  VoiceCallSessionState build() => VoiceCallSessionState(
      status: VoiceCallStatus.connected,
      isMuted: muted,
      hasConnected: true,
      currentAiText: 'お名前を教えてください。');
  @override
  Future<void> initialize(VoiceCallSessionRequest request) async {}
  @override
  Future<bool> resumeMicrophone() async {
    resumeCalls++;
    state = state.copyWith(microphoneInterrupted: false);
    return true;
  }

  @override
  Future<bool> requestHelp(GeminiLiveHelpAction action,
      {String? targetText}) async {
    this.action = action;
    this.targetText = targetText;
    return true;
  }
}

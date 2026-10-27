import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/services/tts_service.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_guided_reading_step.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fixtures/fake_tts.dart';
import '../fixtures/lesson_resume_fixture.dart';

void main() {
  testWidgets(
      'step transition cancels audio and preserves answers without server writes',
      (tester) async {
    final h = await _openPage(tester);
    h.actions.goToVocabLearning();
    h.actions.goToGrammarLearning();
    h.actions.goToGuidedReading();
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    expect(h.audio.service.playback.value.isActive, isTrue);
    final previousAnswers =
        h.container.read(lessonSessionProvider(resumeLessonId)).answers;
    h.actions.goBack();
    await tester.pump();
    expect(h.audio.service.playback.value.phase, TtsPlaybackPhase.idle);
    expect(h.audio.players.single.wantsPlayback, isFalse);
    expect(h.repository.startCalls, 0);
    expect(h.repository.submitCalls, 0);
    expect(h.container.read(lessonSessionProvider(resumeLessonId)).answers,
        previousAnswers);
    await tester.pumpAndSettle();
    await h.close(tester);
  });

  testWidgets('system back stops sentence queue before going to previous stage',
      (tester) async {
    final h = await _openPage(tester);
    h.actions.goToVocabLearning();
    h.actions.goToGrammarLearning();
    h.actions.goToGuidedReading();
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    await tester.binding.handlePopRoute();
    expect(h.audio.service.playback.value.phase, TtsPlaybackPhase.idle);
    expect(h.audio.players.single.wantsPlayback, isFalse);
    await tester.pumpAndSettle();
    expect(h.repository.startCalls, 0);
    expect(h.repository.submitCalls, 0);
    await h.close(tester);
  });

  testWidgets(
      'X cancels audio immediately while preserving saved lesson on pop/reopen',
      (tester) async {
    final h = await _openPage(tester);
    h.actions.goToVocabLearning();
    h.actions.goToGrammarLearning();
    h.actions.goToGuidedReading();
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    await tester.tap(find
        .descendant(of: find.byType(AppBar), matching: find.byType(IconButton))
        .first);
    expect(h.audio.service.playback.value.phase, TtsPlaybackPhase.idle);
    expect(h.audio.players.single.wantsPlayback, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('레슨 목록'), findsOneWidget);
    expect(h.store.values, isNotEmpty);
    unawaited(h.router.push('/lesson'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonGuidedReadingStep), findsOneWidget);
    expect(h.repository.startCalls, 0);
    expect(h.repository.submitCalls, 0);
    await h.close(tester);
  });

  testWidgets(
      'late disposal of an old page preserves the new same-lesson playback owner',
      (tester) async {
    final h = await _openPage(tester);
    h.actions.goToVocabLearning();
    h.actions.goToGrammarLearning();
    h.actions.goToGuidedReading();
    await tester.pumpAndSettle();
    var keepOldPage = true;
    late StateSetter updateHost;
    const newPageKey = ValueKey('new-lesson-page');
    // Retain the old page until the replacement has started its own audio,
    // reproducing the ordering of a late route reverse-transition teardown.
    await tester.pumpWidget(UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp(
        home: StatefulBuilder(builder: (context, setState) {
          updateHost = setState;
          return Stack(children: [
            if (keepOldPage)
              LessonPage(
                  key: const ValueKey('old-lesson-page'),
                  lessonId: resumeLessonId,
                  ttsService: h.audio.service),
            LessonPage(
                key: newPageKey,
                lessonId: resumeLessonId,
                ttsService: h.audio.service),
          ]);
        }),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byKey(newPageKey), matching: find.text('전체 듣기')));
    await _pumpTts(tester);
    final newOwner = h.audio.service.playback.value.owner;
    final newPlayer = h.audio.players.single;
    expect(h.audio.service.playback.value.phase, TtsPlaybackPhase.playing);
    updateHost(() => keepOldPage = false);
    await tester.pump();
    expect(find.byType(LessonPage), findsOneWidget);
    expect(h.audio.service.playback.value.owner, same(newOwner));
    expect(h.audio.service.playback.value.phase, TtsPlaybackPhase.playing);
    expect(newPlayer.wantsPlayback, isTrue);
    expect(newPlayer.disposed, isFalse);
    await h.close(tester);
  });
}

class _PageHarness {
  _PageHarness(
      this.audio, this.store, this.repository, this.container, this.router);
  final TtsHarness audio;
  final MemoryCheckpointStore store;
  final ResumeStudyRepository repository;
  final ProviderContainer container;
  final GoRouter router;
  LessonSessionActions get actions =>
      container.read(lessonSessionProvider(resumeLessonId).notifier).actions;
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    router.dispose();
    container.dispose();
    await _pumpTts(tester);
    await tester.runAsync(audio.dispose);
  }
}

Future<_PageHarness> _openPage(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final audio = TtsHarness();
  final store = MemoryCheckpointStore();
  final repository = ResumeStudyRepository();
  final container = ProviderContainer(overrides: [
    currentAccountIdProvider.overrideWithValue('audio-test-account'),
    currentAccountReaderProvider.overrideWithValue(() => 'audio-test-account'),
    lessonCheckpointStoreProvider.overrideWithValue(store),
    sharedPreferencesProvider.overrideWith((ref) => prefs),
    studyRepositoryProvider.overrideWithValue(repository),
  ]);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('레슨 목록'))),
    GoRoute(
        path: '/lesson',
        builder: (_, __) =>
            LessonPage(lessonId: resumeLessonId, ttsService: audio.service)),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: MaterialApp.router(routerConfig: router)));
  unawaited(router.push('/lesson'));
  await tester.pumpAndSettle();
  return _PageHarness(audio, store, repository, container, router);
}

Future<void> _pumpTts(WidgetTester tester) async {
  await tester.runAsync(() => flushTts());
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

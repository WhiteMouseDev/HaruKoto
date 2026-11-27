import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/services/tts_service.dart';
import 'package:harukoto_mobile/features/kana/domain/kana_writing_progress.dart';
import 'package:harukoto_mobile/features/kana/domain/katakana_pilot.dart';
import 'package:harukoto_mobile/features/kana/presentation/katakana_pilot_page.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_writing_audio_provider.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_writing_progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../fixtures/fake_tts.dart';

final _ownerProvider = NotifierProvider<_Owner, String>(_Owner.new);

class _Owner extends Notifier<String> {
  @override
  String build() => 'writer-a';
  void change(String value) => state = value;
}

void main() {
  late TtsHarness h;
  late SharedPreferences prefs;

  setUp(() async {
    h = TtsHarness();
    SharedPreferences.setMockInitialValues({
      'katakana_pilot_review.v1.writer-a.u': true,
      'hiragana_pilot_review.v1.writer-a.u': true,
      'existing-learning-record': 8,
    });
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpAudio(tester);
    await tester.runAsync(h.dispose);
  }

  testWidgets('listen stop replay and take over from a character to an example',
      (tester) async {
    await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    expect(h.requests, isEmpty);
    final before = _snapshot(prefs);
    await _tap(tester, 'kana-writing-character-audio', key: true);
    expect(h.requests.single.path, '/kana/tts');
    expect(h.requests.single.data, {'text': 'ア'});
    expect(h.service.playback.value.phase, TtsPlaybackPhase.playing);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    expect(h.requests.last.data, {'text': 'あいす'});
    expect(h.players.first.wantsPlayback, false);
    expect(h.players.last.wantsPlayback, true);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    expect(h.players, hasLength(3));
    expect(h.requests,
        hasLength(2)); // Existing URL cache serves repeat listening.
    expect(_snapshot(prefs), before);
    await finish(tester);
  });

  testWidgets('recall keeps the visual answer hidden while allowing sound',
      (tester) async {
    await _pump(tester, prefs, h, hiragana: true);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    await _tap(tester, '가리고 쓰기');
    expect(find.text('あ'), findsNothing);
    expect(find.text('あめ'), findsNothing);
    await _tap(tester, 'kana-writing-character-audio', key: true);
    expect(h.requests.last.data, {'text': 'あ'});
    expect(find.text('あ'), findsNothing);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    expect(h.requests.last.data, {'text': HiraganaPilotLetter.a.wordReading});
    expect(find.text(HiraganaPilotLetter.a.word), findsNothing);
    await finish(tester);
  });

  testWidgets('small kana and counters use contextual reading only',
      (tester) async {
    await _pump(tester, prefs, h);
    await _tap(tester, 'ヵ・ヶ');
    expect(find.byKey(const ValueKey('kana-writing-character-audio')),
        findsNothing);
    expect(find.text('표기 읽기 듣기'), findsOneWidget);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    expect(h.requests.last.data,
        {'text': KatakanaPilotLetter.smallKa.wordReading});
    await finish(tester);
  });

  testWidgets('stage changes stop pending lookup and late result never plays',
      (tester) async {
    final response = Completer<ResponseBody>();
    h.respond = (_) => response.future;
    await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    expect(find.text('음성 준비 중'), findsOneWidget);
    await _tap(tester, '가리고 쓰기');
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    response.complete(_audioResponse());
    await _pumpAudio(tester);
    expect(h.players, isEmpty);
    expect(find.text('1/5 글자 · 2/3 단계'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('picker exit stops audio and resuming never auto plays',
      (tester) async {
    await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    await _tap(tester, '가리고 쓰기');
    await _tap(tester, 'kana-writing-example-audio', key: true);
    await _tap(tester, 'kana-writing-picker', key: true);
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    expect(h.players.single.wantsPlayback, false);
    await _tap(tester, 'kana-writing-resume', key: true);
    expect(find.text('1/5 글자 · 2/3 단계'), findsOneWidget);
    expect(h.players, hasLength(1));
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    await finish(tester);
  });

  testWidgets('next character stops existing audio', (tester) async {
    await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    await _tap(tester, '가리고 쓰기');
    await _tap(tester, '쓰기 건너뛰기');
    await _tap(tester, 'katakana-word-character-0', key: true);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    await _tap(tester, '다음 글자');
    expect(h.players.single.wantsPlayback, false);
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    expect(find.text('2/5 글자 · 1/3 단계'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('background stops playback and returning stays silent',
      (tester) async {
    await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    await _tap(tester, 'kana-writing-character-audio', key: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _pumpAudio(tester);
    expect(h.players.single.wantsPlayback, false);
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpAudio(tester);
    expect(h.players, hasLength(1));
    await finish(tester);
  });

  testWidgets('dispose cancels delayed lookup without stopping a newer owner',
      (tester) async {
    final response = Completer<ResponseBody>();
    h.respond = (_) => response.future;
    await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    await tester.pumpWidget(const SizedBox.shrink());
    final newer = Object();
    unawaited(h.service.playUrl('https://audio.test/newer.mp3', owner: newer));
    await _pumpAudio(tester);
    response.complete(_audioResponse());
    await _pumpAudio(tester);
    expect(h.players, hasLength(1));
    expect(h.service.playback.value.owner, same(newer));
    expect(h.players.single.wantsPlayback, true);
    await finish(tester);
  });

  testWidgets('account switch cancels a pending lookup and keeps old records',
      (tester) async {
    final response = Completer<ResponseBody>();
    h.respond = (_) => response.future;
    final container = await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    await _tap(tester, 'kana-writing-character-audio', key: true);
    final before = _snapshot(prefs);
    container.read(_ownerProvider.notifier).change('writer-b');
    await _pumpAudio(tester);
    response.complete(_audioResponse());
    await _pumpAudio(tester);
    expect(h.players, isEmpty);
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    expect(_snapshot(prefs), before);
    await finish(tester);
  });

  testWidgets('failed speech has Korean retry and does not block writing',
      (tester) async {
    var fail = true;
    h.respond =
        (_) async => fail ? _audioResponse(status: 503) : _audioResponse();
    await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    final before = _snapshot(prefs);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    expect(
        find.byKey(const ValueKey('kana-writing-audio-error')), findsOneWidget);
    expect(find.textContaining('서버 오류'), findsOneWidget);
    expect(_snapshot(prefs), before);
    fail = false;
    await _tap(tester, 'kana-writing-audio-retry', key: true);
    expect(h.requests, hasLength(2));
    expect(h.service.playback.value.phase, TtsPlaybackPhase.playing);
    expect(
        find.byKey(const ValueKey('kana-writing-audio-error')), findsNothing);
    await _tap(tester, '가리고 쓰기');
    expect(find.text('1/5 글자 · 2/3 단계'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('kana-writing-audio-error')), findsNothing);
    await finish(tester);
  });

  testWidgets('failed speech does not leave a stale error on the next step',
      (tester) async {
    h.respond = (_) async => _audioResponse(status: 503);
    await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    await _tap(tester, 'kana-writing-example-audio', key: true);
    expect(
        find.byKey(const ValueKey('kana-writing-audio-error')), findsOneWidget);
    await _tap(tester, '가리고 쓰기');
    expect(
        find.byKey(const ValueKey('kana-writing-audio-error')), findsNothing);
    expect(
        find.byKey(const ValueKey('kana-writing-audio-retry')), findsNothing);
    await finish(tester);
  });

  for (final config in [(320.0, 1.0), (390.0, 1.4), (320.0, 2.0)]) {
    testWidgets('loading and failure keep the drawing pad fixed at $config',
        (tester) async {
      final response = Completer<ResponseBody>();
      h.respond = (_) => response.future;
      await _pump(tester, prefs, h, width: config.$1, textScale: config.$2);
      await _tap(tester, 'kana-writing-recommendation', key: true);
      await _tap(tester, '가리고 쓰기');
      final canvas = find.byKey(const ValueKey('katakana-recall-canvas'));
      await tester.ensureVisible(canvas);
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(canvas);
      // Invoke the real button action without scrolling back away from the pad.
      tester
          .widget<OutlinedButton>(
              find.byKey(const ValueKey('kana-writing-example-audio')))
          .onPressed!();
      await _pumpAudio(tester);
      expect(tester.getTopLeft(canvas), before);
      final gesture = await tester.startGesture(tester.getCenter(canvas));
      await gesture.moveBy(const Offset(20, -20));
      response.complete(_audioResponse(status: 503));
      await _pumpAudio(tester);
      expect(tester.getTopLeft(canvas), before);
      expect(find.byKey(const ValueKey('kana-writing-audio-error')),
          findsOneWidget);
      await gesture.moveBy(const Offset(30, -20));
      await gesture.up();
      await tester.pumpAndSettle();
      final saved =
          prefs.getString('kana_writing_progress.v1.writer-a.katakana')!;
      expect(
          KanaWritingProgress.decode(saved,
                  const KanaWritingScope(owner: 'writer-a', hiragana: false))
              .session!
              .strokes,
          hasLength(1));
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  }

  testWidgets(
      'daily review uses alternate word and preserves a general checkpoint',
      (tester) async {
    final container = await _pump(tester, prefs, h);
    await _tap(tester, 'kana-writing-recommendation', key: true);
    await _tap(tester, '가리고 쓰기');
    const scope = KanaWritingScope(owner: 'writer-a', hiragana: false);
    final checkpoint =
        container.read(kanaWritingProgressProvider(scope)).progress!.encode();
    await _tap(tester, 'kana-writing-picker', key: true);
    await _tap(tester, '새 단어로 복습');
    const letter = KatakanaPilotLetter.u;
    await _tap(tester, 'kana-writing-example-audio', key: true);
    expect(h.requests.last.data, {'text': letter.reviewWord.reading});
    expect(
        container.read(kanaWritingProgressProvider(scope)).progress!.encode(),
        checkpoint);
    await finish(tester);
  });
}

Map<String, Object?> _snapshot(SharedPreferences prefs) => {
      for (final key in prefs.getKeys()) key: prefs.get(key),
    };

Future<ProviderContainer> _pump(
    WidgetTester tester, SharedPreferences prefs, TtsHarness h,
    {bool hiragana = false, double width = 900, double textScale = 1}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentAccountIdProvider.overrideWith((ref) => ref.watch(_ownerProvider)),
      currentAccountReaderProvider
          .overrideWith((ref) => () => ref.read(_ownerProvider)),
      kanaWritingTtsServiceProvider.overrideWithValue(h.service),
    ],
    child: MaterialApp(
        builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: KanaPilotPage(hiragana: hiragana)),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(KanaPilotPage)));
}

Future<void> _pumpAudio(WidgetTester tester) async {
  // Dio's queued interceptors use fake timers while its response stream can
  // finish in the real async zone. Drain both sides of that boundary.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(flushTts);
  }
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _tap(WidgetTester tester, String label, {bool key = false}) async {
  final finder = key ? find.byKey(ValueKey(label)) : find.text(label);
  if (finder.evaluate().isEmpty) await tester.scrollUntilVisible(finder, 180);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _pumpAudio(tester);
  await tester.pumpAndSettle();
}

ResponseBody _audioResponse({int status = 200}) => ResponseBody.fromString(
        status == 200 ? '{"audioUrl":"https://audio.test/kana.mp3"}' : '{}',
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });

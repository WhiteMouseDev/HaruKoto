import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/services/tts_service.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_dialogue_audio_control.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_dialogue_sheet.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_guided_reading_step.dart';

import '../../../../fixtures/fake_tts.dart';

void main() {
  late TtsHarness h;

  testWidgets(
      'whole dialogue is available without combined URL and can stop/replay',
      (tester) async {
    h = TtsHarness();
    await tester.pumpWidget(_app(_control(h)));
    expect(find.text('대화 전체 듣기'), findsOneWidget);
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    expect(find.text('재생 중 · 1/2문장'), findsOneWidget);
    h.players.single.complete();
    await _pumpTts(tester);
    expect(find.text('재생 중 · 2/2문장'), findsOneWidget);
    await tester.tap(find.text('정지'));
    await _pumpTts(tester);
    expect(find.text('다시 듣기'), findsOneWidget);
    await tester.tap(find.text('다시 듣기'));
    await _pumpTts(tester);
    expect(h.players.last.played.single, contains('/script-lines/0/tts'));
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });

  testWidgets('loading has usable stop control; late lookup never starts',
      (tester) async {
    h = TtsHarness();
    final response = Completer<ResponseBody>();
    h.respond = (_) => response.future;
    await tester.pumpWidget(_app(_control(h)));
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    expect(find.textContaining('음성 준비 중'), findsOneWidget);
    await tester.tap(find.text('정지'));
    response.complete(ResponseBody.fromString('{}', 200));
    await _pumpTts(tester);
    expect(h.players, isEmpty);
    expect(find.text('다시 듣기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });

  testWidgets('failure is in Korean and retry starts from first sentence',
      (tester) async {
    h = TtsHarness();
    var fail = true;
    h.respond = (_) async => ResponseBody.fromString(
          fail ? '{}' : '{"audioUrl":"https://audio.test/retry.mp3"}',
          fail ? 503 : 200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
    await tester.pumpWidget(_app(_control(h)));
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    expect(find.textContaining('서버 오류'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('다시 듣기'));
    await _pumpTts(tester);
    expect(h.requests.last.path, contains('/script-lines/0/tts'));
    expect(find.byKey(const ValueKey('dialogue-audio-error')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });

  testWidgets('removing screen during lookup cancels late playback',
      (tester) async {
    h = TtsHarness();
    final response = Completer<ResponseBody>();
    h.respond = (_) => response.future;
    await tester.pumpWidget(_app(_control(h)));
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(ResponseBody.fromString(
        '{"audioUrl":"https://audio.test/late.mp3"}', 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        }));
    await _pumpTts(tester);
    expect(h.players, isEmpty);
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    await _dispose(tester, h);
  });

  testWidgets('background cancels playback and resume does not auto restart',
      (tester) async {
    h = TtsHarness();
    await tester.pumpWidget(_app(_control(h)));
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _pumpTts(tester);
    expect(h.players.single.wantsPlayback, isFalse);
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpTts(tester);
    expect(h.players, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });

  testWidgets('scrolling whole control out of view does not cancel dialogue',
      (tester) async {
    h = TtsHarness();
    await tester.pumpWidget(_app(ListView(children: [
      _control(h),
      ...List.generate(35, (i) => SizedBox(height: 100, child: Text('문장 $i'))),
    ])));
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(h.service.playback.value.phase, TtsPlaybackPhase.playing);
    h.players.single.complete();
    await _pumpTts(tester);
    expect(h.players, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });

  testWidgets(
      'blank sentences keep original indices and empty reading has no control',
      (tester) async {
    h = TtsHarness();
    const reading = ReadingModel(script: [
      ScriptLineModel(voiceId: 'test', speaker: 'A', text: ' '),
      ScriptLineModel(voiceId: 'test', speaker: 'B', text: 'はい。'),
    ]);
    await tester.pumpWidget(_app(_control(h, reading: reading)));
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    expect(h.requests.single.path, contains('/script-lines/1/tts'));
    expect(find.text('재생 중 · 1/1문장'), findsOneWidget);
    await tester
        .pumpWidget(_app(_control(h, reading: const ReadingModel(script: []))));
    await _pumpTts(tester);
    expect(find.text('전체 듣기'), findsNothing);
    expect(h.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });

  testWidgets(
      'existing combined URL with no script still plays without a new endpoint',
      (tester) async {
    h = TtsHarness();
    await tester.pumpWidget(_app(_control(h,
        reading: const ReadingModel(
            script: [], audioUrl: 'https://audio.test/combined.mp3'))));
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    expect(h.players.single.audible, ['https://audio.test/combined.mp3']);
    expect(h.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });

  testWidgets(
      'guided reading next cancels before practice callback and manual line replaces queue',
      (tester) async {
    h = TtsHarness();
    var nextCalled = false;
    await tester.pumpWidget(_app(LessonGuidedReadingStep(
      detail: _detail,
      ttsService: h.service,
      onNext: () {
        expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
        nextCalled = true;
      },
    )));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    await tester.tap(find.byTooltip('음성 듣기').last);
    await _pumpTts(tester);
    expect(h.players.last.played.single, contains('/script-lines/1/tts'));
    expect(h.service.playback.value.isDialogue, isFalse);
    await tester.tap(find.text('이해 체크로'));
    expect(nextCalled, isTrue);
    expect(h.players.last.wantsPlayback, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });

  testWidgets(
      'sheet pop cancels immediately before reverse transition and late lookup',
      (tester) async {
    h = TtsHarness();
    final response = Completer<ResponseBody>();
    h.respond = (_) => response.future;
    late BuildContext parentContext;
    await tester.pumpWidget(_app(Builder(builder: (context) {
      parentContext = context;
      return TextButton(
          onPressed: () => unawaited(
              showLessonDialogueSheet(context, _detail, ttsService: h.service)),
          child: const Text('대화 열기'));
    })));
    await tester.tap(find.text('대화 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    Navigator.of(parentContext).pop();
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
    response.complete(ResponseBody.fromString(
        '{"audioUrl":"https://audio.test/late.mp3"}', 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        }));
    await tester.pump();
    expect(h.players, isEmpty);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });

  testWidgets('narrow layout and large text keep playback/error actions usable',
      (tester) async {
    h = TtsHarness();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    h.respond = (_) async => ResponseBody.fromString('{}', 503);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(
          size: Size(390, 844), textScaler: TextScaler.linear(2)),
      child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: _control(h))),
    )));
    await tester.tap(find.text('전체 듣기'));
    await _pumpTts(tester);
    expect(find.text('다시 듣기'), findsOneWidget);
    expect(find.textContaining('서버 오류'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _dispose(tester, h);
  });
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));
Widget _control(TtsHarness h, {ReadingModel reading = _reading}) =>
    LessonDialogueAudioControl(
        lessonId: 'lesson', reading: reading, ttsService: h.service);
Future<void> _pumpTts(WidgetTester tester) async {
  await tester.runAsync(() => flushTts());
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

const _reading = ReadingModel(script: [
  ScriptLineModel(voiceId: 'test', speaker: 'キム', text: '私は映画が好きです。'),
  ScriptLineModel(voiceId: 'test', speaker: '田中', text: '私も映画が好きです。'),
]);
const _detail = LessonDetailModel(
    id: 'lesson',
    lessonNo: 4,
    chapterLessonNo: 4,
    title: '공통점이 반가울 때',
    topic: '취미',
    estimatedMinutes: 10,
    content: LessonContentModel(reading: _reading, questions: []),
    vocabItems: [],
    grammarItems: []);

Future<void> _dispose(WidgetTester tester, TtsHarness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _pumpTts(tester);
  await tester.runAsync(harness.dispose);
}

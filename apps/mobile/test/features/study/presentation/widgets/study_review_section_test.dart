import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/review_summary_model.dart';
import 'package:harukoto_mobile/features/study/presentation/quiz_launch.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/study_review_section.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_pilot_telemetry_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  testWidgets(
      'known zero differs from a failed read and exposes no quiz action',
      (tester) async {
    final fixture = await _pump(tester, read: () async => _summary());
    expect(find.text('지금 복습할 표현이 없어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-summary-retry')), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(fixture.launches, isEmpty);
  });

  testWidgets('initial error is Korean and retry does not replay a failed read',
      (tester) async {
    final pending = Completer<ReviewSummaryModel>();
    var reads = 0;
    final fixture = await _pump(tester, read: () {
      reads++;
      return reads == 1 ? Future.error(_timeout()) : pending.future;
    });
    expect(find.text('복습 현황을 확인하지 못했어요.'), findsOneWidget);
    expect(find.text('서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('레슨 학습은 계속할 수 있어요.'), findsOneWidget);
    expect(find.textContaining('RequestOptions'), findsNothing);
    expect(find.text('지금 복습할 표현이 없어요'), findsNothing);

    final retry = tester
        .widget<OutlinedButton>(
            find.byKey(const ValueKey('review-summary-retry')))
        .onPressed!;
    retry();
    retry();
    retry();
    await tester.pump();
    expect(reads, 2);
    expect(find.text('복습 현황을 불러오고 있어요.'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    pending.complete(_summary(words: 3));
    await tester.pumpAndSettle();
    expect(find.text('단어 최대 3개 복습'), findsOneWidget);
    expect(fixture.launches, isEmpty);
  });

  testWidgets(
      'refresh hides retained counts through pending and another failure',
      (tester) async {
    final pending = Completer<ReviewSummaryModel>();
    var reads = 0;
    final fixture = await _pump(tester,
        read: () => ++reads == 1
            ? Future.value(_summary(words: 12, grammar: 2))
            : pending.future);
    expect(find.text('복습할 표현 14개'), findsOneWidget);
    fixture.container.invalidate(reviewSummaryProvider('N5'));
    await tester.pump();
    expect(find.text('복습할 표현 14개'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    pending.completeError(_timeout());
    await tester.pumpAndSettle();
    expect(find.text('복습 현황을 확인하지 못했어요.'), findsOneWidget);
    expect(find.text('복습할 표현 14개'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  for (final (words, grammar, type, count) in [
    (2, 5, 'VOCABULARY', 2),
    (2, 5, 'GRAMMAR', 5),
    (12, 2, 'VOCABULARY', 10),
    (0, 14, 'GRAMMAR', 10),
  ]) {
    testWidgets('explicit $type action opens its own $count-item batch once',
        (tester) async {
      final fixture = await _pump(tester,
          read: () async => _summary(words: words, grammar: grammar));
      final button = find.byKey(ValueKey('review-category-$type'));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      final launch = tester.widget<FilledButton>(button).onPressed!;
      launch();
      launch();
      launch();
      expect(fixture.launches, hasLength(1));
      expect(fixture.events, hasLength(1));
      final request = fixture.launches.single;
      expect(request.quizType, type);
      expect(request.count, count);
      expect(request.mode, 'review');
      expect(request.jlptLevel, 'N5');
      expect(request.stageId, isNull);
      expect(request.sourceSessionId, isNull);
      expect(fixture.events.single.properties['quizType'], type);
      await tester.pumpAndSettle();
      expect(find.text('복습 테스트 화면'), findsOneWidget);
    });
  }

  testWidgets(
      'returning from a review refreshes counts before another category',
      (tester) async {
    var reads = 0;
    final fixture = await _pump(tester,
        read: () async => ++reads == 1
            ? _summary(words: 2, grammar: 5)
            : _summary(grammar: 5));
    await tester.tap(find.byKey(const ValueKey('review-category-VOCABULARY')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(
        find.byKey(const ValueKey('review-category-VOCABULARY')), findsNothing);
    expect(find.text('문법 최대 5개 복습'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('review-category-GRAMMAR')));
    expect(fixture.launches.map((e) => e.quizType), ['VOCABULARY', 'GRAMMAR']);
  });

  testWidgets('beginner return refreshes the selected key, not an N5 cache',
      (tester) async {
    var selectedReads = 0;
    var n5Reads = 0;
    final level = ValueNotifier('ABSOLUTE_ZERO');
    addTearDown(level.dispose);
    final fixture = await _pump(tester,
        level: level,
        read: () async => ++selectedReads == 1
            ? _summary(words: 2, grammar: 5)
            : _summary(grammar: 5),
        readN5: () async {
          n5Reads++;
          return _summary(words: 8);
        });
    final cache =
        fixture.container.listen(reviewSummaryProvider('N5'), (_, __) {});
    addTearDown(cache.close);
    await fixture.container.read(reviewSummaryProvider('N5').future);
    expect(n5Reads, 1);

    await tester.tap(find.byKey(const ValueKey('review-category-VOCABULARY')));
    await tester.pumpAndSettle();
    expect(fixture.launches.single.jlptLevel, 'N5');
    expect(fixture.events.single.properties['jlptLevel'], 'ABSOLUTE_ZERO');
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
    expect(selectedReads, 2);
    expect(n5Reads, 1);
    expect(
        find.byKey(const ValueKey('review-category-VOCABULARY')), findsNothing);
    expect(find.text('문법 최대 5개 복습'), findsOneWidget);
  });

  testWidgets('a stale button cannot open a quiz after account changes',
      (tester) async {
    final identity = _Identity();
    final fixture = await _pump(tester,
        identity: identity, read: () async => _summary(words: 2));
    final action = tester
        .widget<FilledButton>(
            find.byKey(const ValueKey('review-category-VOCABULARY')))
        .onPressed!;
    identity.current = 'other-account';
    action();
    await tester.pump();
    expect(fixture.launches, isEmpty);
    expect(fixture.events, isEmpty);
  });

  testWidgets('return after an account switch does not refresh its old summary',
      (tester) async {
    var reads = 0;
    final identity = _Identity();
    await _pump(tester, identity: identity, read: () async {
      reads++;
      return _summary(words: 2);
    });
    await tester.tap(find.byKey(const ValueKey('review-category-VOCABULARY')));
    await tester.pumpAndSettle();
    identity.current = 'other-account';
    await tester.tap(find.text('돌아가기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(reads, 1);
    expect(find.text('복습 현황을 불러오고 있어요.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets(
      'level change replaces old counts and old return cannot reread it',
      (tester) async {
    var reads = 0;
    final level = ValueNotifier('N5');
    addTearDown(level.dispose);
    await _pump(tester,
        level: level,
        read: () async =>
            ++reads == 1 ? _summary(words: 2) : _summary(grammar: 4));
    await tester.tap(find.byKey(const ValueKey('review-category-VOCABULARY')));
    await tester.pumpAndSettle();
    level.value = 'N4';
    await tester.pump();
    await tester.tap(find.text('돌아가기'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('문법 최대 4개 복습'), findsOneWidget);
    expect(find.text('단어 최대 2개 복습'), findsNothing);
  });

  testWidgets('a previously rendered level action cannot use another level',
      (tester) async {
    final level = ValueNotifier('N5');
    addTearDown(level.dispose);
    final fixture =
        await _pump(tester, level: level, read: () async => _summary(words: 2));
    final oldAction = tester
        .widget<FilledButton>(
            find.byKey(const ValueKey('review-category-VOCABULARY')))
        .onPressed!;
    level.value = 'N4';
    await tester.pumpAndSettle();
    oldAction();
    expect(fixture.launches, isEmpty);
    expect(fixture.events, isEmpty);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320px large text fits both category buttons in $brightness',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(tester,
          read: () async => _summary(words: 12, grammar: 14),
          brightness: brightness,
          textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('단어 최대 10개 복습'), findsOneWidget);
      expect(find.text('문법 최대 10개 복습'), findsOneWidget);
    });
  }
}

class _Identity {
  String? current = 'test-account';
}

class _Fixture {
  _Fixture(this.container, this.launches, this.events);
  final ProviderContainer container;
  final List<QuizLaunchRequest> launches;
  final List<LessonPilotEvent> events;
}

Future<_Fixture> _pump(WidgetTester tester,
    {required Future<ReviewSummaryModel> Function() read,
    Future<ReviewSummaryModel> Function()? readN5,
    _Identity? identity,
    ValueNotifier<String>? level,
    Brightness brightness = Brightness.light,
    double textScale = 1}) async {
  final account = identity ?? _Identity();
  final launches = <QuizLaunchRequest>[];
  final events = <LessonPilotEvent>[];
  final selectedLevel = level ?? ValueNotifier('N5');
  if (level == null) addTearDown(selectedLevel.dispose);
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    currentAccountIdProvider.overrideWithValue('test-account'),
    currentAccountReaderProvider.overrideWithValue(() => account.current),
    reviewSummaryProvider('N5').overrideWith((ref) => (readN5 ?? read)()),
    reviewSummaryProvider('N4').overrideWith((ref) => read()),
    reviewSummaryProvider('ABSOLUTE_ZERO').overrideWith((ref) => read()),
    lessonPilotTelemetrySinkProvider.overrideWithValue(events.add),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ValueListenableBuilder<String>(
              valueListenable: selectedLevel,
              builder: (_, level, __) => StudyReviewSection(
                jlptLevel: level,
                mapEnabled: true,
                routeBuilder: (request) {
                  launches.add(request);
                  return MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                            body: Column(children: [
                              const Text('복습 테스트 화면'),
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('돌아가기')),
                            ]),
                          ));
                },
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return _Fixture(container, launches, events);
}

ReviewSummaryModel _summary({int words = 0, int grammar = 0}) =>
    ReviewSummaryModel(
        wordDue: words,
        grammarDue: grammar,
        totalDue: words + grammar,
        wordNew: 0,
        grammarNew: 0);

DioException _timeout() => DioException(
    requestOptions: RequestOptions(path: '/lessons/review/summary'),
    type: DioExceptionType.connectionTimeout,
    message: 'RequestOptions internal diagnostic');

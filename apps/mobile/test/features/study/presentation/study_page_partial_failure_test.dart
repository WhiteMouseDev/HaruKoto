import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/core/network/network_base.dart';
import 'package:harukoto_mobile/core/providers/dio_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/data/models/review_summary_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_page.dart';
import 'package:harukoto_mobile/features/study/presentation/study_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_continue_banner.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_chapter_list.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/study_kana_section.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_pilot_telemetry_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StudyPage dashboard isolation', () {
    testWidgets('fresh dashboard failure keeps lessons usable with showKana on',
        (tester) async {
      final fixture = await _pump(tester, dashboard: _timeout);
      await _settleDashboard(tester, fixture);

      expect(tester.takeException(), isNull);
      expect(find.text('가나 학습 현황을 불러오지 못했어요.'), findsOneWidget);
      expect(find.text('서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.textContaining('RequestOptions'), findsNothing);
      expect(find.text('0/0'), findsNothing);
      expect(fixture.repository.chapterReads, 1);
      expect(fixture.repository.reviewReads, 1);
      await _openLesson(tester, fixture);
    });

    testWidgets('pending dashboard does not delay reviews or lesson navigation',
        (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final fixture = await _pump(tester, dashboard: () => pending.future);

      expect(fixture.repository.chapterReads, 1);
      expect(fixture.repository.reviewReads, 1);
      expect(find.text('가나 학습 현황을 불러오고 있어요.'), findsOneWidget);
      await _openLesson(tester, fixture);
      pending.complete(_dashboard());
      await tester.pump();
    });

    for (final learned in [0, 12]) {
      testWidgets('successful known progress shows the actual $learned/92',
          (tester) async {
        final fixture = await _pump(tester,
            dashboard: () async => _dashboard(learned: learned));
        await _settleDashboard(tester, fixture);

        expect(find.text('가나 부트캠프'), findsOneWidget);
        expect(find.text('$learned/92'), findsOneWidget);
        expect(find.text('가나 학습 현황을 불러오지 못했어요.'), findsNothing);
        final progress = tester.widget<LinearProgressIndicator>(
          find.descendant(
            of: find.byType(StudyKanaSection),
            matching: find.byType(LinearProgressIndicator),
          ),
        );
        expect(progress.value, learned / 92);
      });
    }

    testWidgets('known completed kana still hides the bootcamp card',
        (tester) async {
      final fixture = await _pump(tester,
          dashboard: () async => _dashboard(learned: 46, katakanaLearned: 46));
      await _settleDashboard(tester, fixture);

      expect(find.text('가나 부트캠프'), findsNothing);
      expect(find.text('가나 학습 현황'), findsNothing);
      expect(fixture.repository.chapterReads, 1);
    });

    for (final (description, response) in [
      ('missing progress', <String, dynamic>{'showKana': true}),
      ('zero totals', _dashboard(total: 0)),
      (
        'one unknown total',
        {
          'kanaProgress': {
            'hiragana': {'learned': 0, 'total': 46},
            'katakana': {'learned': 0, 'total': 0},
          },
        }
      ),
    ]) {
      testWidgets(
          '$description shows unavailable progress and keeps kana access',
          (tester) async {
        final fixture = await _pump(tester, dashboard: () async => response);
        await _settleDashboard(tester, fixture);

        expect(find.text('가나 진도를 확인할 수 없어요.'), findsOneWidget);
        _expectNoKanaProgress(tester);
        await _openKana(tester);
      });
    }

    for (final state in ['pending', 'failure', 'success']) {
      testWidgets(
          'showKana off ignores a dashboard $state from another surface',
          (tester) async {
        final pending = Completer<Map<String, dynamic>>();
        final fixture = await _pump(tester, showKana: false, dashboard: () {
          if (state == 'pending') return pending.future;
          if (state == 'failure') return _timeout();
          return Future.value({..._dashboard(), 'showKana': true});
        });
        // Simulate the home surface keeping its shared dashboard subscribed.
        final subscription =
            fixture.container.listen(dashboardProvider, (_, __) {});
        addTearDown(subscription.close);
        if (state == 'pending') {
          await tester.pump(const Duration(milliseconds: 1));
        } else {
          await _settleDashboard(tester, fixture);
        }

        expect(find.byType(StudyKanaSection), findsNothing);
        expect(find.text('가나 학습 현황'), findsNothing);
        expect(find.text('가나 부트캠프'), findsNothing);
        await _openLesson(tester, fixture);
        if (state == 'pending') pending.complete(_dashboard());
      });
    }

    testWidgets(
        'retry is dashboard-only, disabled while pending, then shows data',
        (tester) async {
      final response = Completer<Map<String, dynamic>>();
      var reads = 0;
      final fixture = await _pump(tester,
          dashboard: () => ++reads == 1 ? _timeout() : response.future);
      await _settleDashboard(tester, fixture);
      final retry = find.widgetWithText(OutlinedButton, '다시 불러오기');
      await tester.ensureVisible(retry);
      await tester.pump();
      final previousAction = tester.widget<OutlinedButton>(retry).onPressed!;
      await tester.tap(retry);
      // A second event before rebuilding must not schedule another request.
      previousAction();
      previousAction();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(tester.widget<OutlinedButton>(retry).onPressed, isNull);
      await tester.tap(retry);
      await tester.pump();
      expect(reads, 2);
      expect(fixture.requests, hasLength(2));
      expect(fixture.repository.chapterReads, 1);
      expect(fixture.repository.reviewReads, 1);
      _expectNoKanaProgress(tester);

      response.complete(_dashboard(learned: 25));
      await _settleDashboard(tester, fixture);
      expect(find.text('25/92'), findsOneWidget);
      expect(find.text('다시 불러오기'), findsNothing);
      expect(reads, 2);
    });

    testWidgets(
        'repeated retry failures remain recoverable without fake progress',
        (tester) async {
      final fixture = await _pump(tester, dashboard: _timeout);
      await _settleDashboard(tester, fixture);
      for (var attempt = 2; attempt <= 3; attempt++) {
        final retry = find.widgetWithText(OutlinedButton, '다시 불러오기');
        await tester.ensureVisible(retry);
        await tester.pump();
        await tester.tap(retry);
        await _settleDashboard(tester, fixture);
        expect(find.text('가나 학습 현황을 불러오지 못했어요.'), findsOneWidget);
        expect(tester.widget<OutlinedButton>(retry).onPressed, isNotNull);
        expect(fixture.requests, hasLength(attempt));
        expect(fixture.repository.chapterReads, 1);
        expect(fixture.repository.reviewReads, 1);
        _expectNoKanaProgress(tester);
      }
      await _openLesson(tester, fixture);
    });

    for (final completed in [false, true]) {
      testWidgets(
          'cached completed=$completed refresh failure hides stale progress',
          (tester) async {
        final response = Completer<Map<String, dynamic>>();
        var reads = 0;
        final fixture = await _pump(tester, dashboard: () async {
          if (++reads == 1) {
            return _dashboard(
                learned: completed ? 46 : 12,
                katakanaLearned: completed ? 46 : 0);
          }
          return response.future;
        });
        await _settleDashboard(tester, fixture);
        expect(find.text('12/92'), completed ? findsNothing : findsOneWidget);
        fixture.container.invalidate(dashboardProvider);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        // A previously completed card occupied no space. Revisit the bottom
        // section after refresh makes its pending placeholder visible again.
        await tester.scrollUntilVisible(find.byType(StudyKanaSection), 300,
            scrollable: _outerScrollable);
        await tester.pump();
        expect(find.text('가나 학습 현황을 불러오고 있어요.'), findsOneWidget);
        expect(find.text('12/92'), findsNothing);

        response.completeError(_transportError());
        await _settleDashboard(tester, fixture);
        expect(find.text('가나 학습 현황을 불러오지 못했어요.'), findsOneWidget);
        expect(find.textContaining('RequestOptions'), findsNothing);
        _expectNoKanaProgress(tester);
        expect(fixture.repository.chapterReads, 1);
        expect(fixture.repository.reviewReads, 1);
      });
    }

    testWidgets(
        'successful refresh replaces cached progress with the actual result',
        (tester) async {
      final response = Completer<Map<String, dynamic>>();
      var reads = 0;
      final fixture = await _pump(tester,
          dashboard: () =>
              ++reads == 1 ? Future.value(_dashboard()) : response.future);
      await _settleDashboard(tester, fixture);
      expect(find.text('12/92'), findsOneWidget);
      fixture.container.invalidate(dashboardProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('가나 학습 현황을 불러오고 있어요.'), findsOneWidget);
      expect(find.text('12/92'), findsNothing);
      response.complete(_dashboard(learned: 30));
      await _settleDashboard(tester, fixture);
      expect(find.text('30/92'), findsOneWidget);
      expect(find.text('12/92'), findsNothing);
    });

    testWidgets('dashboard failure still permits opening the kana screen',
        (tester) async {
      final fixture = await _pump(tester, dashboard: _timeout);
      await _settleDashboard(tester, fixture);
      await _openKana(tester);
      expect(fixture.requests, hasLength(1));
    });

    testWidgets(
        'chapter lesson CTA still opens a lesson after dashboard failure',
        (tester) async {
      final fixture = await _pump(tester, dashboard: _timeout);
      await _settleDashboard(tester, fixture);
      await tester.scrollUntilVisible(find.byType(LessonChapterList), -300,
          scrollable: _outerScrollable);
      await tester.pump();
      // The original integration has a collapsed station presentation; the
      // main branch uses the expanded chapter list. Exercise its actual row.
      final stationToggle =
          find.byKey(const ValueKey('station-toggle-chapter-1'));
      if (stationToggle.evaluate().isNotEmpty) {
        await tester.ensureVisible(stationToggle);
        await tester.pump();
        await tester.tap(stationToggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }
      final lesson = find
          .descendant(
            of: find.byType(LessonChapterList),
            matching: find.text('레슨 목록 확인'),
          )
          .last;
      await tester.ensureVisible(lesson);
      await tester.pump();
      await tester.tap(lesson);
      await _expectLessonOpened(tester, fixture);
    });

    for (final brightness in Brightness.values) {
      testWidgets('kana error actions fit 320px at 200% text in $brightness',
          (tester) async {
        tester.view.physicalSize = const Size(320, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final fixture = await _pump(tester,
              dashboard: _timeout,
              sectionOnly: true,
              brightness: brightness,
              textScale: 2);
          await _settleDashboard(tester, fixture);

          expect(tester.takeException(), isNull);
          final retry = find.widgetWithText(OutlinedButton, '다시 불러오기');
          final open = find.widgetWithText(TextButton, '가나 학습 열기');
          expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(open).height, greaterThanOrEqualTo(48));
          expect(
              find.bySemanticsLabel(RegExp('가나 학습 현황.*다시 불러오기', dotAll: true)),
              findsOneWidget);
          await _openKana(tester);
        } finally {
          semantics.dispose();
        }
      });
    }
  });
}

void _expectNoKanaProgress(WidgetTester tester) {
  expect(find.text('0/0'), findsNothing);
  expect(find.text('0/92'), findsNothing);
  final progress = tester.widgetList<LinearProgressIndicator>(find.descendant(
      of: find.byType(StudyKanaSection),
      matching: find.byType(LinearProgressIndicator)));
  expect(progress.every((indicator) => indicator.value == null), isTrue);
}

Future<void> _openKana(WidgetTester tester) async {
  await tester.ensureVisible(find.text('가나 학습 열기'));
  await tester.pump();
  await tester.tap(find.text('가나 학습 열기'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  expect(find.text('가나 상세 화면'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _settleDashboard(WidgetTester tester, _Fixture fixture) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 1));
    if (!fixture.container.read(dashboardProvider).isLoading) break;
  }
  await tester.pump();
  await tester.pump();
}

Future<void> _openLesson(WidgetTester tester, _Fixture fixture) async {
  await tester.scrollUntilVisible(find.byType(LessonContinueBanner), -300,
      scrollable: _outerScrollable);
  await tester.pump();
  await tester.tap(find.byType(LessonContinueBanner));
  await _expectLessonOpened(tester, fixture);
}

Future<void> _expectLessonOpened(WidgetTester tester, _Fixture fixture) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  expect(find.byType(LessonPage), findsOneWidget);
  expect(GoRouterState.of(tester.element(find.byType(LessonPage))).uri.path,
      '/study/lessons/lesson-1');
  expect(find.text('레슨 상세 확인'), findsWidgets);
  expect(fixture.repository.detailReads, ['lesson-1']);
  expect(fixture.repository.writes, 0);
  expect(tester.takeException(), isNull);
}

typedef _DashboardRead = Future<Map<String, dynamic>> Function();

Finder get _outerScrollable => find
    .descendant(
        of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
    .first;

class _Fixture {
  const _Fixture(this.container, this.router, this.repository, this.requests);

  final ProviderContainer container;
  final GoRouter router;
  final _StudyRepository repository;
  final List<RequestOptions> requests;
}

Future<_Fixture> _pump(
  WidgetTester tester, {
  required _DashboardRead dashboard,
  bool showKana = true,
  bool sectionOnly = false,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({
    'user_show_kana': showKana,
    'user_jlpt_level': 'N5',
    'auth_test_sentinel': 'keep-session',
    'study_test_sentinel': 'keep-progress',
  });
  final prefs = await SharedPreferences.getInstance();
  final originalPreferences = {
    for (final key in prefs.getKeys()) key: prefs.get(key),
  };
  final requests = <RequestOptions>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
    requests.add(options);
    if (options.method != 'GET' || options.path != '/stats/dashboard') {
      handler.reject(DioException(
        requestOptions: options,
        error: StateError('Unexpected request in read-only study fixture'),
      ));
      return;
    }
    try {
      handler.resolve(Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
        data: await dashboard(),
      ));
    } catch (error) {
      handler.reject(
        error is DioException
            ? error.copyWith(requestOptions: options)
            : DioException(requestOptions: options, error: error),
        true,
      );
    }
  }));
  dio.interceptors.add(AppErrorInterceptor());
  final repository = _StudyRepository();
  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      dioProvider.overrideWithValue(dio),
      // Keep unrelated calendar refresh timers outside this view-state fixture;
      // the real repository still performs every dashboard GET below.
      dashboardProvider.overrideWith(
        (ref) => ref.watch(homeRepositoryProvider).fetchDashboard(),
      ),
      authSessionManagerProvider.overrideWith(
        (ref) =>
            throw StateError('Auth must not be touched by a display retry'),
      ),
      authRefreshClientProvider.overrideWith(
        (ref) => throw StateError('Auth refresh must not be touched'),
      ),
      studyRepositoryProvider.overrideWithValue(repository),
      lessonPilotTelemetrySinkProvider.overrideWithValue((_) {}),
    ],
  );
  // Keep the shared read alive when a completed, zero-height kana section is
  // temporarily outside the viewport, as another app surface may also do.
  final dashboardSubscription =
      showKana ? container.listen(dashboardProvider, (_, __) {}) : null;
  final router = GoRouter(initialLocation: '/study', routes: [
    GoRoute(
        path: '/study',
        builder: (_, __) => sectionOnly
            ? Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                padding: const EdgeInsets.all(20),
                child: StudyKanaSection(
                    dataBuilder: (_) => const Text('가나 정상 현황')),
              )))
            : const StudyPage()),
    GoRoute(
      path: '/study/lessons/:lessonId',
      builder: (_, state) =>
          LessonPage(lessonId: state.pathParameters['lessonId']!),
    ),
    GoRoute(
      path: '/study/kana',
      builder: (_, __) => const Scaffold(body: Text('가나 상세 화면')),
    ),
  ]);
  addTearDown(() {
    expect(repository.writes, 0);
    expect(
        requests
            .every((r) => r.method == 'GET' && r.path == '/stats/dashboard'),
        isTrue);
    expect({for (final key in prefs.getKeys()) key: prefs.get(key)},
        originalPreferences);
    router.dispose();
    dashboardSubscription?.close();
    container.dispose();
    dio.close(force: true);
  });
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
  if (showKana && !sectionOnly) {
    // The existing station UI may mount this bottom sliver only after it
    // enters the viewport. A completed section has no height or visible target.
    for (var i = 0; i < 3; i++) {
      final position = tester.state<ScrollableState>(_outerScrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
    }
  }
  return _Fixture(container, router, repository, requests);
}

Future<Map<String, dynamic>> _timeout() async {
  throw _transportError();
}

DioException _transportError() => DioException(
      requestOptions: RequestOptions(path: '/stats/dashboard'),
      type: DioExceptionType.connectionTimeout,
      message: 'RequestOptions.connectTimeout internal details',
    );

Map<String, dynamic> _dashboard(
        {int learned = 12, int total = 46, int katakanaLearned = 0}) =>
    {
      'showKana': false,
      'kanaProgress': {
        'hiragana': {'learned': learned, 'total': total, 'pct': 26.1},
        'katakana': {'learned': katakanaLearned, 'total': total, 'pct': 0},
      },
    };

class _StudyRepository extends Fake implements StudyRepository {
  int chapterReads = 0;
  int reviewReads = 0;
  int writes = 0;
  final detailReads = <String>[];

  @override
  Future<ChapterListModel> fetchChapters(String jlptLevel) async {
    chapterReads++;
    return const ChapterListModel(chapters: [
      ChapterModel(
        id: 'chapter-1',
        jlptLevel: 'N5',
        partNo: 1,
        chapterNo: 1,
        title: '테스트 챕터',
        completedLessons: 0,
        totalLessons: 1,
        lessons: [
          LessonSummaryModel(
            id: 'lesson-1',
            lessonNo: 1,
            chapterLessonNo: 1,
            title: '레슨 목록 확인',
            topic: '인사',
            estimatedMinutes: 5,
            status: 'NOT_STARTED',
            scoreCorrect: 0,
            scoreTotal: 0,
          )
        ],
      ),
    ]);
  }

  @override
  Future<ReviewSummaryModel> fetchReviewSummary(String jlptLevel) async {
    reviewReads++;
    return const ReviewSummaryModel(
        wordDue: 2, grammarDue: 3, totalDue: 5, wordNew: 0, grammarNew: 0);
  }

  @override
  Future<LessonDetailModel> fetchLessonDetail(String lessonId) async {
    detailReads.add(lessonId);
    return const LessonDetailModel(
      id: 'lesson-1',
      lessonNo: 1,
      chapterLessonNo: 1,
      title: '레슨 상세 확인',
      topic: '인사',
      estimatedMinutes: 5,
      content:
          LessonContentModel(reading: ReadingModel(script: []), questions: []),
      vocabItems: [],
      grammarItems: [],
    );
  }

  @override
  Future<LessonProgressModel> startLesson(String lessonId) async {
    writes++;
    throw StateError('Display and dashboard retry must not start a lesson');
  }

  @override
  Future<LessonSubmitResultModel> submitLesson(
      String lessonId, List<Map<String, dynamic>> answers) async {
    writes++;
    throw StateError('Display and dashboard retry must not save progress');
  }
}

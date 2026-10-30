import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/core/constants/colors.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_recommendation.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_chapter_list.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/legacy_lesson_chapter_list.dart';
import 'package:harukoto_mobile/features/study/providers/study_map_config.dart';

void main() {
  testWidgets(
      'first visit shows one train at the recommended unstarted station',
      (tester) async {
    final chapters = [
      _chapter(1, statuses: List.filled(5, 'NOT_STARTED')),
      _chapter(5),
    ];
    await _pump(tester, chapters);

    expect(find.byKey(const ValueKey('station-train')), findsOneWidget);
    expect(find.byType(LegacyLessonChapterList), findsNothing);
    final signSize =
        tester.getSize(find.byKey(const ValueKey('station-sign-N5-01')));
    expect(signSize.width, greaterThanOrEqualTo(56));
    expect(signSize.width, signSize.height);
    expect(_within(1, find.byKey(const ValueKey('station-train'))),
        findsOneWidget);
    expect(
        tester.widget(find.byKey(const ValueKey('station-node-recommended'))),
        isA<CustomPaint>());
    expect(_within(1, find.text('추천 역')), findsOneWidget);
    expect(_within(1, find.text('0/5 레슨')), findsOneWidget);
    expect(find.text('0 / 2개 역 완료'), findsOneWidget);
    expect(find.text('이어할 역'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('station-toggle-chapter-5')));
    await tester.pumpAndSettle();
    expect(find.text('레슨 5-1'), findsOneWidget);
    expect(_within(1, find.byKey(const ValueKey('station-train'))),
        findsOneWidget);
    expect(find.byKey(const ValueKey('station-train')), findsOneWidget);
    expect(chapters.first.completedLessons, 0);
    expect(
        chapters.first.lessons
            .every((lesson) => lesson.status == 'NOT_STARTED'),
        isTrue);
  });

  testWidgets('later practice resumes without marking earlier stations done',
      (tester) async {
    final chapters = [
      _chapter(1),
      _chapter(5, statuses: ['IN_PROGRESS', 'NOT_STARTED']),
    ];
    await _pump(tester, chapters);

    expect(find.text('0 / 2개 역 완료'), findsOneWidget);
    expect(_within(1, find.byKey(const ValueKey('station-node-idle'))),
        findsOneWidget);
    expect(_within(5, find.text('이어할 역')), findsOneWidget);
    expect(_within(5, find.byKey(const ValueKey('station-node-resume'))),
        findsOneWidget);
    expect(find.text('레슨 5-1'), findsNothing);
    expect(find.text('레슨 1-1'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('station-highlight-chapter-5')),
        matching: find.byKey(const ValueKey('station-node-resume')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('station-toggle-chapter-5')));
    await tester.pumpAndSettle();
    expect(find.text('레슨 5-1'), findsOneWidget);
    expect(find.text('레슨 1-1'), findsNothing);
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('multiple in-progress stations keep deterministic recommendation',
      (tester) async {
    final chapters = [
      _chapter(1, statuses: ['IN_PROGRESS']),
      _chapter(5, statuses: ['IN_PROGRESS']),
    ];
    await _pump(tester, chapters);
    expect(findRecommendedLesson(chapters)?.lesson.id, 'lesson-1-1');
    expect(_within(1, find.text('이어할 역')), findsOneWidget);
    expect(_within(5, find.text('학습 중')), findsOneWidget);
    expect(find.byKey(const ValueKey('station-node-resume')), findsOneWidget);
  });

  testWidgets('out-of-order completion counts stations independently',
      (tester) async {
    await _pump(tester, [
      _chapter(1),
      _chapter(2, statuses: ['COMPLETED', 'NOT_STARTED']),
      _chapter(5, statuses: ['COMPLETED']),
      _chapter(6, statuses: []),
    ]);
    expect(find.text('1 / 4개 역 완료'), findsOneWidget);
    expect(_within(1, find.text('추천 역')), findsOneWidget);
    expect(_within(2, find.text('학습 중')), findsOneWidget);
    expect(_within(5, find.text('완료')), findsOneWidget);
    expect(_within(6, find.text('완료')), findsNothing);
    expect(find.byKey(const ValueKey('station-node-resume')), findsNothing);
  });

  testWidgets('fully completed route has checkmarks without a current station',
      (tester) async {
    await _pump(tester, [
      _chapter(1, statuses: ['COMPLETED']),
      _chapter(5, statuses: ['COMPLETED']),
    ]);
    expect(find.text('2 / 2개 역 완료'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('station-node-complete')), findsNWidgets(2));
    expect(find.text('이어할 역'), findsNothing);
    expect(find.text('추천 역'), findsNothing);
    expect(find.byKey(const ValueKey('station-train')), findsNothing);
    expect(find.text('다시 학습'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('station-toggle-chapter-1')));
    await tester.pumpAndSettle();
    expect(find.text('다시 학습'), findsOneWidget);
  });

  testWidgets('browsing does not move recommendation or lose choice on refresh',
      (tester) async {
    List<ChapterModel> chapters() => [
          _chapter(1),
          _chapter(5, statuses: ['IN_PROGRESS']),
        ];
    await _pump(tester, chapters());
    await tester.tap(find.byKey(const ValueKey('station-toggle-chapter-5')));
    await tester.pumpAndSettle();
    expect(find.text('레슨 5-1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('station-toggle-chapter-1')));
    await tester.pumpAndSettle();
    expect(find.text('레슨 1-1'), findsOneWidget);
    expect(find.text('레슨 5-1'), findsNothing);
    expect(_within(5, find.text('이어할 역')), findsOneWidget);
    expect(_within(5, find.byKey(const ValueKey('station-train'))),
        findsOneWidget);
    expect(find.byKey(const ValueKey('station-train')), findsOneWidget);
    expect(find.byKey(const ValueKey('station-highlight-chapter-1')),
        findsNothing);
    expect(find.byKey(const ValueKey('station-highlight-chapter-5')),
        findsOneWidget);

    await _pump(tester, chapters());
    expect(find.text('레슨 1-1'), findsOneWidget);
    expect(find.text('레슨 5-1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('station-toggle-chapter-1')));
    await tester.pumpAndSettle();
    await _pump(tester, chapters());
    expect(find.text('레슨 1-1'), findsNothing);
    expect(find.text('레슨 5-1'), findsNothing);

    await _pump(tester, [_chapter(1, level: 'N4')]);
    expect(find.text('N4'), findsWidgets);
    expect(find.text('레슨 1-1'), findsNothing);
  });

  testWidgets(
      'recommendation refresh keeps stations collapsed until explicitly opened',
      (tester) async {
    await _pump(tester, [_chapter(1), _chapter(5)]);
    expect(find.text('레슨 1-1'), findsNothing);
    expect(_within(1, find.byKey(const ValueKey('station-train'))),
        findsOneWidget);
    await _pump(tester, [
      _chapter(1),
      _chapter(5, statuses: ['IN_PROGRESS']),
    ]);
    expect(_within(5, find.text('이어할 역')), findsOneWidget);
    expect(tester.widget(find.byKey(const ValueKey('station-node-resume'))),
        isA<CustomPaint>());
    expect(
        _within(1, find.byKey(const ValueKey('station-train'))), findsNothing);
    expect(_within(5, find.byKey(const ValueKey('station-train'))),
        findsOneWidget);
    expect(find.byKey(const ValueKey('station-train')), findsOneWidget);
    expect(find.text('레슨 5-1'), findsNothing);
    expect(find.text('레슨 1-1'), findsNothing);
  });

  testWidgets('unstarted future station and lesson can be opened freely',
      (tester) async {
    final chapters = [_chapter(1), _chapter(5)];
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(child: _list(chapters)),
        ),
      ),
      GoRoute(
        path: '/study/lessons/:id',
        builder: (context, state) =>
            Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('station-toggle-chapter-5')));
    await tester.pumpAndSettle();
    final lesson = find.byKey(const ValueKey('station-lesson-lesson-5-1'));
    await tester.ensureVisible(lesson);
    await tester.tap(lesson);
    await tester.pumpAndSettle();
    expect(find.text('Opened lesson-5-1'), findsOneWidget);
    expect(chapters.first.completedLessons, 0);
    expect(chapters.last.lessons.single.status, 'NOT_STARTED');
  });

  testWidgets('repeated chapter numbers show their part in station signs',
      (tester) async {
    await _pump(tester, [_chapter(1), _chapter(1, part: 2)]);
    expect(find.text('N5 · 1부'), findsOneWidget);
    expect(find.text('N5 · 2부'), findsOneWidget);
    expect(find.text('01'), findsNWidgets(2));
    final semantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('station-semantics-chapter-2-1')),
    );
    expect(semantics.properties.label, contains('N5 2-01역'));
  });

  testWidgets('station exposes an actionable screen-reader toggle',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, [_chapter(1), _chapter(5)]);
    final node = tester.getSemantics(
      find.byKey(const ValueKey('station-semantics-chapter-5')),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.label, contains('시작 전'));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(find.text('레슨 5-1'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('source flag restores the original chapter list and lesson tiles',
      (tester) async {
    await _pump(tester, [_chapter(1)], enabled: false);
    expect(find.byType(LegacyLessonChapterList), findsOneWidget);
    expect(find.byType(ChapterCard), findsOneWidget);
    expect(find.byType(LessonTile), findsOneWidget);
    expect(find.text('Ch.1'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    expect(find.text('N5 학습 노선'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('fits $brightness ${width}px at text scale $scale',
            (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 1100));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await _pump(
            tester,
            [
              _chapter(1, statuses: ['IN_PROGRESS', 'NOT_STARTED'], long: true),
              _chapter(5, statuses: ['COMPLETED'], long: true),
              _chapter(100, part: 2, long: true),
            ],
            brightness: brightness,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('N5 · 2부'), findsOneWidget);
          expect(find.text('100'), findsOneWidget);
          final text =
              tester.widget<Text>(find.text('아주 긴 학습 챕터 제목 인사와 자기소개 1'));
          expect(text.maxLines, isNull);
          await tester
              .tap(find.byKey(const ValueKey('station-toggle-chapter-1')));
          await tester.pumpAndSettle();
          expect(find.text('아주 긴 레슨 이름 주문하고 요청하는 표현'), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
              find.byKey(const ValueKey('station-toggle-chapter-5')));
          await tester
              .tap(find.byKey(const ValueKey('station-toggle-chapter-5')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Finder _within(int chapter, Finder matching) => find.descendant(
      of: find.byKey(ValueKey('station-chapter-$chapter')),
      matching: matching,
    );

Widget _list(List<ChapterModel> chapters) => LessonChapterList(
      chapters: chapters,
      recommendedLessonId: findRecommendedLesson(chapters)?.lesson.id,
    );

Future<void> _pump(
  WidgetTester tester,
  List<ChapterModel> chapters, {
  bool? enabled,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (enabled != null) studyMapEnabledProvider.overrideWithValue(enabled),
      ],
      child: MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: brightness,
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(child: _list(chapters)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ChapterModel _chapter(
  int number, {
  List<String> statuses = const ['NOT_STARTED'],
  String level = 'N5',
  int part = 1,
  bool long = false,
}) =>
    ChapterModel(
      id: part == 1 ? 'chapter-$number' : 'chapter-$part-$number',
      jlptLevel: level,
      partNo: part,
      chapterNo: number,
      title: long ? '아주 긴 학습 챕터 제목 인사와 자기소개 $number' : '챕터 $number',
      completedLessons: statuses.where((s) => s == 'COMPLETED').length,
      totalLessons: statuses.length,
      lessons: [
        for (var i = 0; i < statuses.length; i++)
          LessonSummaryModel(
            id: 'lesson-$number-${i + 1}',
            lessonNo: number * 10 + i,
            chapterLessonNo: i + 1,
            title: long ? '아주 긴 레슨 이름 주문하고 요청하는 표현' : '레슨 $number-${i + 1}',
            topic: long ? '식당에서 정중하게 주문하고 요청할 수 있어요' : '일상 표현',
            estimatedMinutes: 5,
            status: statuses[i],
            scoreCorrect: statuses[i] == 'COMPLETED' ? 5 : 0,
            scoreTotal: statuses[i] == 'COMPLETED' ? 5 : 0,
          ),
      ],
    );

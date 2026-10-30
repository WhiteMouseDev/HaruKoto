import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/constants/colors.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/data/models/review_summary_model.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_list_page.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_page.dart';
import 'package:harukoto_mobile/features/study/presentation/study_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/saved_lesson_section.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_continue_banner.dart';
import 'package:harukoto_mobile/features/study/providers/saved_lesson_entry_provider.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_recommendation.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_pilot_telemetry_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_map_config.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_station_list.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/legacy_lesson_chapter_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lesson_resume_fixture.dart';
import '../fixtures/saved_lesson_entry_fixture.dart';

void main() {
  testWidgets('many saved lessons render one primary card and a view-all entry',
      (tester) async {
    final store = _WidgetStore();
    for (final id in ['first', 'second', 'third', 'later']) {
      store.values['account-a/$id'] = rawCheckpoint(id);
    }
    await _mount(tester, sectionOnly: true, store: store);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.text('모두 보기 · 4개'), findsOneWidget);
  });

  testWidgets(
      'forty saved lessons keep one card and the last lazy row is reachable',
      (tester) async {
    final store = _WidgetStore();
    for (var i = 0; i < 40; i++) {
      final id = 'lesson-${i.toString().padLeft(2, '0')}';
      store.values['account-a/$id'] = _timedDraft(id, 1000 + i);
    }
    final before = Map<String, String>.from(store.values);
    final f = await _mount(tester,
        sectionOnly: true,
        store: store,
        addDefaultDraft: false,
        repositoryOverride: _ManyLessonsRepository());
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.text('저장 레슨 39'), findsOneWidget);
    expect(find.text('모두 보기 · 40개'), findsOneWidget);
    await tester.tap(find.text('모두 보기 · 40개'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile).evaluate().length, lessThan(40));
    await tester.scrollUntilVisible(find.text('저장 레슨 00'), 500,
        scrollable: find
            .descendant(
                of: find.byType(BottomSheet), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.widgetWithText(ListTile, '저장 레슨 00'));
    await tester.pumpAndSettle();
    expect(f.opened, ['lesson-00']);
    expect(find.byType(BottomSheet), findsNothing);
    expect(store.values, before);
    expect(f.repository.fetchCalls, 0);
    expect(f.repository.submitCalls, 0);
  });

  for (final fullList in [false, true]) {
    for (final mapEnabled in [null, false]) {
      testWidgets(
          'route and recent saved card coexist on fullList=$fullList map=$mapEnabled',
          (tester) async {
        final store = _WidgetStore();
        store.values['account-a/first'] = _timedDraft('first', 1000);
        store.values['account-a/second'] = rawCheckpoint('second');
        store.values['account-a/later'] = _timedDraft('later', 2000);
        final before = Map<String, String>.from(store.values);
        final f = await _mount(tester,
            fullList: fullList, mapEnabled: mapEnabled, store: store);
        final section = find.byType(SavedLessonSection);
        expect(
            find.descendant(of: section, matching: find.byType(OutlinedButton)),
            findsOneWidget);
        expect(find.descendant(of: section, matching: find.text('저장 레슨 later')),
            findsOneWidget);
        expect(find.byType(LessonContinueBanner), findsNothing);
        expect(find.text('모두 보기 · 3개'), findsOneWidget);
        if (mapEnabled == false) {
          expect(find.byType(LegacyLessonChapterList), findsOneWidget);
          expect(find.byType(LessonStationList), findsNothing);
        } else {
          expect(find.byType(LessonStationList), findsOneWidget);
          expect(find.byType(LegacyLessonChapterList), findsNothing);
          expect(find.byKey(const ValueKey('station-train')), findsOneWidget);
          final signSize =
              tester.getSize(find.byKey(const ValueKey('station-sign-N5-01')));
          expect(signSize.width, greaterThanOrEqualTo(56));
          expect(signSize.width, signSize.height);
          expect(find.text('추천 역'), findsOneWidget);
        }
        await tester.tap(find.text('모두 보기 · 3개'));
        await tester.pumpAndSettle();
        final rows =
            tester.widgetList<ListTile>(find.byType(ListTile)).toList();
        expect(rows.map((row) => (row.title! as Text).data),
            ['저장 레슨 later', '저장 레슨 first', '저장 레슨 second']);
        expect(find.text('최근 학습순 · 이전 저장 기록은 학습 순서'), findsOneWidget);
        expect(store.values, before);
        expect(f.repository.startCalls, 0);
        expect(f.repository.submitCalls, 0);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
        'one primary local card even when it is the recommendation $fullList',
        (tester) async {
      final store = _WidgetStore();
      store.values['account-a/first'] = _timedDraft('first', 2000);
      store.values['account-a/later'] = _timedDraft('later', 1000);
      final f = await _mount(tester, fullList: fullList, store: store);
      final section = find.byType(SavedLessonSection);
      expect(
          find.descendant(of: section, matching: find.byType(OutlinedButton)),
          findsOneWidget);
      expect(find.descendant(of: section, matching: find.text('저장 레슨 first')),
          findsOneWidget);
      expect(find.byType(LessonContinueBanner), findsNothing);
      expect(find.text('모두 보기 · 2개'), findsOneWidget);
      expect(f.repository.startCalls, 0);
      expect(f.repository.submitCalls, 0);
    });
  }

  testWidgets(
      'newest primary and full-list order use study time, legacy remains reachable',
      (tester) async {
    final store = _WidgetStore();
    store.values['account-a/first'] = rawCheckpoint('first');
    store.values['account-a/second'] = _timedDraft('second', 1000);
    store.values['account-a/later'] = _timedDraft('later', 2000);
    await _mount(tester, sectionOnly: true, store: store);
    expect(find.text('저장 레슨 later'), findsOneWidget);
    expect(find.text('저장 레슨 first'), findsNothing);
    await tester.tap(find.text('모두 보기 · 3개'));
    await tester.pumpAndSettle();
    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(rows.map((row) => (row.title! as Text).data),
        ['저장 레슨 later', '저장 레슨 second', '저장 레슨 first']);
    expect(find.text('최근 학습순 · 이전 저장 기록은 학습 순서'), findsOneWidget);
  });

  testWidgets('empty saved list leaves one server recommendation',
      (tester) async {
    final f = await _mount(tester, addDefaultDraft: false);
    expect(find.byType(LessonContinueBanner), findsOneWidget);
    expect(find.text('이어서 학습하기'), findsNothing);
    expect(find.text('모두 보기 · 0개'), findsNothing);
    expect(f.repository.startCalls, 0);
    expect(f.repository.submitCalls, 0);
  });

  testWidgets('local loading replaces the fallback with one saved card',
      (tester) async {
    final gate = Completer<void>();
    final store = _WidgetStore()..readGate = gate;
    await _mount(tester, store: store);
    expect(find.byType(LessonContinueBanner), findsOneWidget);
    expect(find.text('이어서 학습하기'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LessonContinueBanner), findsNothing);
    expect(find.text('이어서 학습하기'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('projection error keeps one server fallback and retry',
      (tester) async {
    final f = await _mount(tester, projectionError: true);
    expect(find.byType(LessonContinueBanner), findsOneWidget);
    expect(find.text('저장 위치 다시 확인'), findsOneWidget);
    expect(find.text('이어서 학습하기'), findsNothing);
    expect(f.repository.startCalls, 0);
    expect(f.repository.submitCalls, 0);
  });

  for (final changeLevel in [false, true]) {
    testWidgets(
        'retained server fallback rejects ${changeLevel ? 'level' : 'account'} switch',
        (tester) async {
      final f = await _mount(tester, addDefaultDraft: false);
      final old = tester
          .widget<LessonContinueBanner>(find.byType(LessonContinueBanner))
          .onTap!;
      if (changeLevel) {
        await f.container
            .read(userPreferencesProvider.notifier)
            .setJlptLevel('N4');
      } else {
        f.account = 'account-b';
        f.container.invalidate(currentAccountIdProvider);
      }
      await tester.pumpAndSettle();
      old();
      await tester.pumpAndSettle();
      expect(f.opened, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'same section State rejects a retained N5 fallback after N4 rebuild',
      (tester) async {
    final f = await _mount(tester,
        sectionOnly: true, sectionFallback: true, addDefaultDraft: false);
    final oldState = tester.state(find.byType(SavedLessonSection));
    final old = tester
        .widget<LessonContinueBanner>(find.byType(LessonContinueBanner))
        .onTap!;
    await f.container.read(userPreferencesProvider.notifier).setJlptLevel('N4');
    await tester.pumpAndSettle();
    expect(identical(tester.state(find.byType(SavedLessonSection)), oldState),
        isTrue);
    expect(find.byType(LessonContinueBanner), findsNothing);
    old();
    await tester.pumpAndSettle();
    expect(f.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final fullList in [false, true]) {
    testWidgets(
        '${fullList ? 'full list' : 'study tab'} exposes later local draft '
        'with one local continuation instead of a duplicate server banner',
        (tester) async {
      final f = await _mount(tester, fullList: fullList);
      expect(find.text('이어서 학습하기'), findsOneWidget);
      expect(find.text('단어 학습 저장 위치'), findsOneWidget);
      expect(find.text('추천 레슨 · Ch.1 · 1/4'), findsNothing);
      expect(find.text('시작하기'), findsNothing);
      expect(f.repository.fetchCalls, 0);
      expect(f.repository.startCalls, 0);
      expect(f.repository.submitCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'real entry navigation restores second vocabulary with one detail GET',
      (tester) async {
    final f = await _mount(tester, sectionOnly: true, realLesson: true);
    await tester.tap(find.text('이어하기'));
    await tester.pumpAndSettle();
    expect(find.text('단어 2/3'), findsOneWidget);
    expect(find.text('猫'), findsOneWidget);
    expect(find.text('이 기기에 저장된 위치에서 이어서 학습해요.'), findsOneWidget);
    expect(f.repository.fetchCalls, 1);
    expect(f.repository.startCalls, 0);
    expect(f.repository.submitCalls, 0);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('이어하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'partial lookup failure leaves another draft usable and retries locally',
      (tester) async {
    final store = _WidgetStore()..failed.add('first');
    store.values['account-a/first'] = rawCheckpoint('first');
    final f = await _mount(tester, sectionOnly: true, store: store);
    expect(find.text('일부 저장 위치를 확인하지 못했어요.'), findsOneWidget);
    expect(find.text('이어하기'), findsOneWidget);
    final raw = Map<String, String>.from(store.values);
    store.failed.clear();
    await tester.tap(find.text('저장 위치 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('이어하기'), findsOneWidget);
    expect(find.text('모두 보기 · 2개'), findsOneWidget);
    expect(find.text('일부 저장 위치를 확인하지 못했어요.'), findsNothing);
    expect(store.values, raw);
    expect(f.repository.fetchCalls, 0);
    expect(f.repository.startCalls, 0);
    expect(f.repository.submitCalls, 0);
  });

  testWidgets(
      'pending payload opens read-only record check instead of ordinary resume',
      (tester) async {
    final store = _WidgetStore();
    store.values['account-a/later'] = rawCheckpoint('later', pending: true);
    final f =
        await _mount(tester, sectionOnly: true, store: store, realLesson: true);
    expect(find.text('제출 기록 확인'), findsOneWidget);
    expect(find.text('이어하기'), findsNothing);
    final raw = Map<String, String>.from(store.values);
    await tester.tap(find.text('기록 확인'));
    await tester.pumpAndSettle();
    expect(find.text('서버 기록 다시 확인'), findsOneWidget);
    expect(find.text('답안 제출하기'), findsNothing);
    expect(f.repository.fetchCalls, 1);
    expect(f.repository.startCalls, 0);
    expect(f.repository.submitCalls, 0);
    expect(store.values, raw);
  });

  testWidgets(
      'account and level switches hide drafts and reject retained callbacks',
      (tester) async {
    final f = await _mount(tester, sectionOnly: true);
    final old = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '이어하기'))
        .onPressed!;
    f.account = 'account-b';
    f.container.invalidate(currentAccountIdProvider);
    await tester.pumpAndSettle();
    expect(find.text('이어서 학습하기'), findsNothing);
    old();
    await tester.pumpAndSettle();
    expect(f.opened, isEmpty);
    f.account = 'account-a';
    f.container.invalidate(currentAccountIdProvider);
    await tester.pumpAndSettle();
    expect(find.text('이어하기'), findsOneWidget);
    await f.container.read(userPreferencesProvider.notifier).setJlptLevel('N4');
    await tester.pumpAndSettle();
    expect(find.text('이어하기'), findsNothing);
    old();
    await tester.pumpAndSettle();
    expect(f.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cached titles disappear when authoritative identity changes before stream delivery',
      (tester) async {
    final f = await _mount(tester, sectionOnly: true);
    final old = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '이어하기'))
        .onPressed!;
    f.account =
        'account-b'; // No currentAccountId invalidation: stream is late.
    await f.container.read(userPreferencesProvider.notifier).setDailyGoal(15);
    await tester.pumpAndSettle();
    expect(find.text('저장 레슨 later'), findsNothing);
    expect(find.text('이어하기'), findsNothing);
    old();
    await tester.pumpAndSettle();
    expect(f.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fourth saved lesson is reachable through a result-only picker',
      (tester) async {
    final store = _WidgetStore();
    for (final id in ['first', 'second', 'third', 'later']) {
      store.values['account-a/$id'] = rawCheckpoint(id);
    }
    final f = await _mount(tester, sectionOnly: true, store: store);
    expect(find.text('이어하기'), findsOneWidget);
    await tester.ensureVisible(find.text('모두 보기 · 4개'));
    await tester.tap(find.text('모두 보기 · 4개'));
    await tester.pumpAndSettle();
    expect(find.text('이어할 레슨 모두 보기'), findsOneWidget);
    final fourth = find.widgetWithText(ListTile, '저장 레슨 later').last;
    await tester.ensureVisible(fourth);
    await tester.tap(fourth);
    await tester.pumpAndSettle();
    expect(f.opened, ['later']);
    expect(find.text('이어할 레슨 모두 보기'), findsNothing);
    expect(f.repository.fetchCalls, 0);
    expect(f.repository.startCalls, 0);
    expect(f.repository.submitCalls, 0);
  });

  testWidgets(
      'picker hides a switched account and old selection cannot navigate',
      (tester) async {
    final store = _WidgetStore();
    for (final id in ['first', 'second', 'third', 'later']) {
      store.values['account-a/$id'] = rawCheckpoint(id);
    }
    final f = await _mount(tester, sectionOnly: true, store: store);
    await tester.ensureVisible(find.text('모두 보기 · 4개'));
    await tester.tap(find.text('모두 보기 · 4개'));
    await tester.pumpAndSettle();
    final old = tester
        .widget<ListTile>(find.widgetWithText(ListTile, '저장 레슨 first').last)
        .onTap!;
    f.account = 'account-b';
    f.container.invalidate(currentAccountIdProvider);
    await tester.pumpAndSettle();
    expect(find.text('저장 레슨 first'), findsNothing);
    expect(find.text('계정이나 학습 레벨이 변경됐어요. 목록을 다시 열어주세요.'), findsOneWidget);
    old();
    await tester.pumpAndSettle();
    expect(f.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double tap opens one route; callbacks after disposal do nothing',
      (tester) async {
    final f = await _mount(tester, sectionOnly: true);
    final old = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '이어하기'))
        .onPressed!;
    old();
    old();
    await tester.pumpAndSettle();
    expect(f.opened, ['later']);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    old();
    await tester.pumpAndSettle();
    expect(f.opened, ['later']);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
        'saved cards and fourth-item picker fit 320px with 200% text $brightness',
        (tester) async {
      final store = _WidgetStore();
      for (final id in ['first', 'second', 'third', 'later']) {
        store.values['account-a/$id'] = rawCheckpoint(id);
      }
      final f = await _mount(tester,
          sectionOnly: true,
          store: store,
          size: const Size(320, 844),
          textScale: 2,
          brightness: brightness);
      final action = tester.widget<Text>(find.text('이어하기').first);
      final cardColor = brightness == Brightness.light
          ? AppColors.lightCard
          : AppColors.darkCard;
      final borderColor = brightness == Brightness.light
          ? AppColors.lightBorder
          : AppColors.darkBorder;
      final subtextColor = brightness == Brightness.light
          ? AppColors.lightSubtext
          : AppColors.darkSubtext;
      final viewAll = tester
          .widget<TextButton>(find.widgetWithText(TextButton, '모두 보기 · 4개'));
      final background =
          Theme.of(tester.element(find.byType(SavedLessonSection)))
              .colorScheme
              .surface;
      expect(
          _contrast(viewAll.style!.foregroundColor!.resolve({})!, background),
          greaterThanOrEqualTo(4.5));
      final tile = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '저장 레슨 first').first);
      final meta = tester.widget<Text>(find.text('N5 · 1번 역 · 1번째 레슨').first);
      expect(tile.style!.backgroundColor!.resolve({}), cardColor);
      expect(tile.style!.side!.resolve({})!.color, borderColor);
      expect(meta.style!.color, subtextColor);
      expect(_contrast(action.style!.color!, cardColor),
          greaterThanOrEqualTo(4.5));
      expect(
          _contrast(meta.style!.color!, cardColor), greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('모두 보기 · 4개'));
      await tester.tap(find.text('모두 보기 · 4개'));
      await tester.pumpAndSettle();
      final row = tester.widget<ListTile>(find.byType(ListTile).first);
      expect((row.subtitle! as Text).style!.color, subtextColor);
      expect(_contrast((row.subtitle! as Text).style!.color!, cardColor),
          greaterThanOrEqualTo(4.5));
      final fourth = find.widgetWithText(ListTile, '저장 레슨 later').last;
      await tester.scrollUntilVisible(find.text('저장 레슨 later'), 300,
          scrollable: find
              .descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(Scrollable))
              .first);
      expect(tester.takeException(), isNull);
      await tester.tap(fourth);
      await tester.pumpAndSettle();
      expect(f.opened, ['later']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'all local reads failing still leaves server lesson entry available',
      (tester) async {
    final store = _WidgetStore()
      ..failed.addAll(['first', 'second', 'third', 'later']);
    final f = await _mount(tester, store: store);
    expect(find.text('저장 위치 다시 확인'), findsOneWidget);
    expect(find.text('이어서 학습하기'), findsNothing);
    expect(find.text('시작하기'), findsOneWidget);
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(f.opened, ['first']);
    expect(f.repository.startCalls, 0);
    expect(f.repository.submitCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker also rejects a retained selection after a level switch',
      (tester) async {
    final store = _WidgetStore();
    for (final id in ['first', 'second', 'third', 'later']) {
      store.values['account-a/$id'] = rawCheckpoint(id);
    }
    final f = await _mount(tester, sectionOnly: true, store: store);
    await tester.ensureVisible(find.text('모두 보기 · 4개'));
    await tester.tap(find.text('모두 보기 · 4개'));
    await tester.pumpAndSettle();
    final old = tester
        .widget<ListTile>(find.widgetWithText(ListTile, '저장 레슨 first').last)
        .onTap!;
    await f.container.read(userPreferencesProvider.notifier).setJlptLevel('N4');
    await tester.pumpAndSettle();
    expect(find.text('저장 레슨 first'), findsNothing);
    expect(find.text('계정이나 학습 레벨이 변경됐어요. 목록을 다시 열어주세요.'), findsOneWidget);
    old();
    await tester.pumpAndSettle();
    expect(f.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'actual repository list GET is shared and projection sends no extra HTTP',
      (tester) async {
    final requests = <String>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add('${options.method} ${options.path}');
      if (options.method != 'GET' || options.path != '/lessons/chapters') {
        handler.reject(DioException(
            requestOptions: options,
            error: StateError(
                'List projection must never send detail/start/submit')));
        return;
      }
      handler.resolve(Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: jsonDecode(_chapterJson) as Map<String, dynamic>));
    }));
    final f = await _mount(tester,
        sectionOnly: true, apiRepository: ApiStudyRepository(dio));
    expect(find.text('이어하기'), findsOneWidget);
    expect(requests, ['GET /lessons/chapters']);
    expect(f.store.operations.where((op) => op.startsWith('write:')), isEmpty);
    expect(f.store.operations.where((op) => op.startsWith('remove:')), isEmpty);
    expect(tester.takeException(), isNull);
    dio.close();
  });
}

class _WidgetStore extends MemoryCheckpointStore {
  final failed = <String>{};
  Completer<void>? readGate;
  @override
  Future<String?> read(String accountId, String lessonId) async {
    await readGate?.future;
    if (failed.contains(lessonId)) {
      throw const LessonCheckpointStorageException();
    }
    return super.read(accountId, lessonId);
  }
}

class _Fixture {
  _Fixture(this.store, this.repository);
  String? account = 'account-a';
  final _WidgetStore store;
  final _DisplayRepository repository;
  final opened = <String>[];
  late ProviderContainer container;
}

Future<_Fixture> _mount(WidgetTester tester,
    {bool fullList = false,
    bool? mapEnabled,
    bool sectionOnly = false,
    bool realLesson = false,
    bool addDefaultDraft = true,
    bool projectionError = false,
    bool sectionFallback = false,
    _WidgetStore? store,
    _DisplayRepository? repositoryOverride,
    ApiStudyRepository? apiRepository,
    Size size = const Size(390, 844),
    double textScale = 1,
    Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'user_jlpt_level': 'N5'});
  final prefs = await SharedPreferences.getInstance();
  final localStore = store ?? _WidgetStore();
  if (addDefaultDraft) {
    localStore.values
        .putIfAbsent('account-a/later', () => rawCheckpoint('later'));
  }
  final repository = repositoryOverride ?? _DisplayRepository();
  final f = _Fixture(localStore, repository);
  f.container = ProviderContainer(retry: (_, __) => null, overrides: [
    if (mapEnabled != null)
      studyMapEnabledProvider.overrideWithValue(mapEnabled),
    currentAccountIdProvider.overrideWith((ref) => f.account),
    currentAccountReaderProvider.overrideWithValue(() => f.account),
    sharedPreferencesProvider.overrideWithValue(prefs),
    lessonCheckpointStoreProvider.overrideWithValue(localStore),
    studyRepositoryProvider.overrideWithValue(apiRepository ?? repository),
    if (projectionError)
      savedLessonEntriesProvider('N5').overrideWith(
          (ref) async => throw StateError('projection unavailable')),
    lessonPilotTelemetrySinkProvider.overrideWithValue((_) {}),
  ]);
  addTearDown(f.container.dispose);
  final router = GoRouter(initialLocation: '/study', routes: [
    GoRoute(
        path: '/study',
        builder: (_, __) => sectionOnly
            ? Scaffold(
                body: SingleChildScrollView(
                    child: _LevelBoundSection(
                        includeRecommendation: sectionFallback)))
            : fullList
                ? const LessonListPage()
                : const StudyPage()),
    GoRoute(
        path: '/study/lessons/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          f.opened.add(id);
          return realLesson
              ? LessonPage(lessonId: id)
              : Scaffold(appBar: AppBar(), body: Text('Opened $id'));
        }),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: f.container,
      child: MaterialApp.router(
          theme: ThemeData(
              brightness: brightness,
              colorScheme: ColorScheme.fromSeed(
                      seedColor: AppColors.primary, brightness: brightness)
                  .copyWith(
                      primary: AppColors.primary,
                      outline: brightness == Brightness.light
                          ? AppColors.lightBorder
                          : AppColors.darkBorder,
                      surfaceContainerLow: brightness == Brightness.light
                          ? AppColors.lightCard
                          : AppColors.darkCard,
                      // These deliberately unusable fallback colors catch accidental
                      // usage of unconfigured M3 variants by the new section.
                      outlineVariant: brightness == Brightness.light
                          ? Colors.black
                          : Colors.white,
                      onSurfaceVariant: Colors.red,
                      surface: brightness == Brightness.light
                          ? AppColors.lightBackground
                          : AppColors.darkBackground,
                      onSurface: brightness == Brightness.light
                          ? AppColors.lightText
                          : AppColors.darkText)),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!))));
  await tester.pumpAndSettle();
  return f;
}

String _timedDraft(String id, int milliseconds) {
  final json = jsonDecode(rawCheckpoint(id)) as Map<String, dynamic>;
  json['lastStudiedAtMs'] = milliseconds;
  return jsonEncode(json);
}

class _LevelBoundSection extends ConsumerWidget {
  const _LevelBoundSection({this.includeRecommendation = false});
  final bool includeRecommendation;
  @override
  Widget build(BuildContext context, WidgetRef ref) => SavedLessonSection(
      jlptLevel: ref.watch(userPreferencesProvider).jlptLevel,
      recommendedLesson: includeRecommendation
          ? findRecommendedLesson(ChapterListModel.fromJson(
                  jsonDecode(_chapterJson) as Map<String, dynamic>)
              .chapters)
          : null);
}

class _DisplayRepository extends ResumeStudyRepository {
  _DisplayRepository() : super(detail: detailFor('later'));
  @override
  Future<ChapterListModel> fetchChapters(String jlptLevel) async =>
      jlptLevel == 'N5'
          ? ChapterListModel.fromJson(
              jsonDecode(_chapterJson) as Map<String, dynamic>)
          : const ChapterListModel(chapters: []);
  @override
  Future<ReviewSummaryModel> fetchReviewSummary(String jlptLevel) async =>
      const ReviewSummaryModel(
          wordDue: 0, grammarDue: 0, totalDue: 0, wordNew: 1, grammarNew: 1);
}

class _ManyLessonsRepository extends _DisplayRepository {
  @override
  Future<ChapterListModel> fetchChapters(String jlptLevel) async =>
      ChapterListModel(chapters: [
        ChapterModel(
            id: 'many',
            jlptLevel: jlptLevel,
            partNo: 1,
            chapterNo: 1,
            title: '많은 레슨',
            completedLessons: 0,
            totalLessons: 40,
            lessons: [
              for (var i = 0; i < 40; i++)
                LessonSummaryModel(
                    id: 'lesson-${i.toString().padLeft(2, '0')}',
                    lessonNo: i + 1,
                    chapterLessonNo: i + 1,
                    title: '저장 레슨 ${i.toString().padLeft(2, '0')}',
                    topic: '인사',
                    estimatedMinutes: 10,
                    status: 'NOT_STARTED',
                    scoreCorrect: 0,
                    scoreTotal: 0)
            ])
      ]);
}

const _chapterJson =
    r'''{"chapters":[{"id":"chapter","jlptLevel":"N5", "partNo":1,
"chapterNo":1,"title":"인사와 첫 만남","completedLessons":0,"totalLessons":4,
"lessons":[
{"id":"first","lessonNo":1,"chapterLessonNo":1,"title":"저장 레슨 first","topic":"인사","status":"NOT_STARTED"},
{"id":"second","lessonNo":2,"chapterLessonNo":2,"title":"저장 레슨 second","topic":"인사","status":"NOT_STARTED"},
{"id":"third","lessonNo":3,"chapterLessonNo":3,"title":"저장 레슨 third","topic":"인사","status":"NOT_STARTED"},
{"id":"later","lessonNo":4,"chapterLessonNo":4,"title":"저장 레슨 later","topic":"인사","status":"NOT_STARTED"}
]}]}''';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}

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
import 'package:harukoto_mobile/features/study/providers/lesson_pilot_telemetry_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lesson_resume_fixture.dart';
import '../fixtures/saved_lesson_entry_fixture.dart';

void main() {
  for (final fullList in [false, true]) {
    testWidgets(
        '${fullList ? 'full list' : 'study tab'} exposes later local draft '
        'without changing the server recommendation', (tester) async {
      final f = await _mount(tester, fullList: fullList);
      expect(find.text('이 기기에 저장된 레슨'), findsOneWidget);
      expect(find.text('단어 학습 저장 위치'), findsOneWidget);
      expect(find.text('추천 레슨 · Ch.1 · 1/4'), findsOneWidget);
      expect(find.text('바로 시작'), findsOneWidget);
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
    await tester.tap(find.text('저장 위치 열기'));
    await tester.pumpAndSettle();
    expect(find.text('단어 2/3'), findsOneWidget);
    expect(find.text('猫'), findsOneWidget);
    expect(find.text('이 기기에 저장된 위치에서 이어서 학습해요.'), findsOneWidget);
    expect(f.repository.fetchCalls, 1);
    expect(f.repository.startCalls, 0);
    expect(f.repository.submitCalls, 0);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('저장 위치 열기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'partial lookup failure leaves another draft usable and retries locally',
      (tester) async {
    final store = _WidgetStore()..failed.add('first');
    store.values['account-a/first'] = rawCheckpoint('first');
    final f = await _mount(tester, sectionOnly: true, store: store);
    expect(find.text('일부 저장 위치를 확인하지 못했어요.'), findsOneWidget);
    expect(find.text('저장 위치 열기'), findsOneWidget);
    final raw = Map<String, String>.from(store.values);
    store.failed.clear();
    await tester.tap(find.text('저장 위치 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('저장 위치 열기'), findsNWidgets(2));
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
    expect(find.text('저장 위치 열기'), findsNothing);
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
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '저장 위치 열기'))
        .onPressed!;
    f.account = 'account-b';
    f.container.invalidate(currentAccountIdProvider);
    await tester.pumpAndSettle();
    expect(find.text('이 기기에 저장된 레슨'), findsNothing);
    old();
    await tester.pumpAndSettle();
    expect(f.opened, isEmpty);
    f.account = 'account-a';
    f.container.invalidate(currentAccountIdProvider);
    await tester.pumpAndSettle();
    expect(find.text('저장 위치 열기'), findsOneWidget);
    await f.container.read(userPreferencesProvider.notifier).setJlptLevel('N4');
    await tester.pumpAndSettle();
    expect(find.text('저장 위치 열기'), findsNothing);
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
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '저장 위치 열기'))
        .onPressed!;
    f.account =
        'account-b'; // No currentAccountId invalidation: stream is late.
    await f.container.read(userPreferencesProvider.notifier).setDailyGoal(15);
    await tester.pumpAndSettle();
    expect(find.text('저장 레슨 later'), findsNothing);
    expect(find.text('저장 위치 열기'), findsNothing);
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
    expect(find.text('저장 위치 열기'), findsNWidgets(3));
    await tester.ensureVisible(find.text('저장된 레슨 4개 모두 보기'));
    await tester.tap(find.text('저장된 레슨 4개 모두 보기'));
    await tester.pumpAndSettle();
    expect(find.text('저장된 레슨 고르기'), findsOneWidget);
    final fourth = find.widgetWithText(OutlinedButton, '저장 레슨 later').last;
    await tester.ensureVisible(fourth);
    await tester.tap(fourth);
    await tester.pumpAndSettle();
    expect(f.opened, ['later']);
    expect(find.text('저장된 레슨 고르기'), findsNothing);
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
    await tester.ensureVisible(find.text('저장된 레슨 4개 모두 보기'));
    await tester.tap(find.text('저장된 레슨 4개 모두 보기'));
    await tester.pumpAndSettle();
    final old = tester
        .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '저장 레슨 first').last)
        .onPressed!;
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
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '저장 위치 열기'))
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
      final action = tester.widget<Text>(find.text('저장 위치 열기').first);
      final cardColor = brightness == Brightness.light
          ? AppColors.lightCard
          : AppColors.darkCard;
      final borderColor = brightness == Brightness.light
          ? AppColors.lightBorder
          : AppColors.darkBorder;
      final subtextColor = brightness == Brightness.light
          ? AppColors.lightSubtext
          : AppColors.darkSubtext;
      final surface = Theme.of(tester.element(find.byType(SavedLessonSection)))
          .colorScheme
          .surface;
      final tile = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '저장 레슨 first').first);
      final meta = tester.widget<Text>(find.text('N5 · 1번 역 · 1번째 레슨').first);
      final description =
          tester.widget<Text>(find.text('학습 순서대로 표시해요. 열면 저장 위치를 확인해요.'));
      expect(tile.style!.backgroundColor!.resolve({}), cardColor);
      expect(tile.style!.side!.resolve({})!.color, borderColor);
      expect(meta.style!.color, subtextColor);
      expect(description.style!.color, subtextColor);
      expect(_contrast(action.style!.color!, cardColor),
          greaterThanOrEqualTo(4.5));
      expect(
          _contrast(meta.style!.color!, cardColor), greaterThanOrEqualTo(4.5));
      expect(_contrast(description.style!.color!, surface),
          greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('저장된 레슨 4개 모두 보기'));
      await tester.tap(find.text('저장된 레슨 4개 모두 보기'));
      await tester.pumpAndSettle();
      final fourth = find.widgetWithText(OutlinedButton, '저장 레슨 later').last;
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
    expect(find.text('이 기기에 저장된 레슨'), findsNothing);
    expect(find.text('바로 시작'), findsOneWidget);
    await tester.tap(find.text('바로 시작'));
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
    await tester.ensureVisible(find.text('저장된 레슨 4개 모두 보기'));
    await tester.tap(find.text('저장된 레슨 4개 모두 보기'));
    await tester.pumpAndSettle();
    final old = tester
        .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '저장 레슨 first').last)
        .onPressed!;
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
    expect(find.text('저장 위치 열기'), findsOneWidget);
    expect(requests, ['GET /lessons/chapters']);
    expect(f.store.operations.where((op) => op.startsWith('write:')), isEmpty);
    expect(f.store.operations.where((op) => op.startsWith('remove:')), isEmpty);
    expect(tester.takeException(), isNull);
    dio.close();
  });
}

class _WidgetStore extends MemoryCheckpointStore {
  final failed = <String>{};
  @override
  Future<String?> read(String accountId, String lessonId) {
    if (failed.contains(lessonId)) {
      return Future.error(const LessonCheckpointStorageException());
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
    bool sectionOnly = false,
    bool realLesson = false,
    _WidgetStore? store,
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
  localStore.values
      .putIfAbsent('account-a/later', () => rawCheckpoint('later'));
  final repository = _DisplayRepository();
  final f = _Fixture(localStore, repository);
  f.container = ProviderContainer(retry: (_, __) => null, overrides: [
    currentAccountIdProvider.overrideWith((ref) => f.account),
    currentAccountReaderProvider.overrideWithValue(() => f.account),
    sharedPreferencesProvider.overrideWithValue(prefs),
    lessonCheckpointStoreProvider.overrideWithValue(localStore),
    studyRepositoryProvider.overrideWithValue(apiRepository ?? repository),
    lessonPilotTelemetrySinkProvider.overrideWithValue((_) {}),
  ]);
  addTearDown(f.container.dispose);
  final router = GoRouter(initialLocation: '/study', routes: [
    GoRoute(
        path: '/study',
        builder: (_, __) => sectionOnly
            ? const Scaffold(
                body: SingleChildScrollView(child: _LevelBoundSection()))
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

class _LevelBoundSection extends ConsumerWidget {
  const _LevelBoundSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) => SavedLessonSection(
      jlptLevel: ref.watch(userPreferencesProvider).jlptLevel);
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

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/auth_session_manager.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/app_http_client.dart';
import 'package:harukoto_mobile/core/network/auth_refresh_client.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/features/home/providers/study_activity_refresh_provider.dart';
import 'package:harukoto_mobile/features/my/data/my_repository.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:harukoto_mobile/features/my/providers/settings_sync_provider.dart';
import 'package:harukoto_mobile/features/study/data/lesson_checkpoint_store.dart';
import 'package:harukoto_mobile/features/study/data/lesson_study_activity_repository.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_submission.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_activity_sync_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/study/fixtures/lesson_activity_fixture.dart';

const _maintenance = '학습 저장을 잠시 점검하고 있어요. 잠시 후 같은 기록으로 다시 시도해주세요.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('STOP503 preserves auth and retries the identical submission body',
      () async {
    final h = _ClientHarness();
    addTearDown(h.dispose);
    final repository = ApiStudyRepository(h.client.dio);
    final draft = LessonSubmissionDraft.create(owner: activityOwner, answers: [
      {'order': 1, 'selectedAnswer': 'b', 'responseMs': 321},
    ]);
    await expectLater(
        repository.submitLessonIdempotent(activityLesson, draft),
        throwsA(isA<LessonSubmissionException>()
            .having((error) => error.statusCode, 'status', 503)
            .having(
                (error) => error.message, 'original detail', _maintenance)));
    expect(h.adapter.requests, hasLength(1));
    h.expectAuthPreserved();

    h.adapter.paused = false;
    final receipt =
        await repository.submitLessonIdempotent(activityLesson, draft);
    expect(receipt.submissionId, draft.submissionId);
    expect(h.adapter.requests, hasLength(2));
    expect(h.adapter.requests.first, h.adapter.requests.last);
    expect(h.adapter.submissions, hasLength(1));
    h.expectAuthPreserved();
  });

  test('STOP503 activity transport has no hidden POST or auth replay',
      () async {
    final h = _ClientHarness();
    addTearDown(h.dispose);
    final repository =
        ApiLessonStudyActivityRepository(h.client.dio, () => activityOwner);
    addTearDown(repository.dispose);
    final draft = activityDraft();
    await expectLater(
        repository.submit(activityLesson, draft),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 503)));
    expect(h.adapter.requests, hasLength(1));
    h.expectAuthPreserved();
    h.adapter.paused = false;
    final receipt = await repository.submit(activityLesson, draft);
    expect(receipt.activityId, draft.activityId);
    expect(receipt.studyDate, '2026-11-03');
    expect(h.adapter.requests, hasLength(2));
    expect(h.adapter.requests.first, h.adapter.requests.last);
    expect(h.adapter.activities, hasLength(1));
  });

  test('STOP503 goal PATCH restores only its confirmed account goal', () async {
    SharedPreferences.setMockInitialValues({
      'user_daily_goal': 40,
      'user_daily_goal_v2:$activityOwner': 20,
      'user_daily_goal_v2:$activityOtherOwner': 30,
    });
    final prefs = await SharedPreferences.getInstance();
    final h = _ClientHarness();
    addTearDown(h.dispose);
    var owner = activityOwner;
    final repository = MyRepository(h.client.dio, currentOwner: () => owner);
    addTearDown(repository.dispose);
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWith((ref) => owner),
      currentAccountReaderProvider.overrideWithValue(() => owner),
      sharedPreferencesProvider.overrideWithValue(prefs),
      myRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await expectLater(
        container.read(settingsSyncServiceProvider).updateDailyGoal(25),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 503)));
    expect(container.read(userPreferencesProvider).dailyGoal, 20);
    expect(container.read(userPreferencesProvider).dailyGoalConfirmed, isTrue);
    expect(prefs.getInt('user_daily_goal_v2:$activityOwner'), 20);
    expect(prefs.getInt('user_daily_goal_v2:$activityOtherOwner'), 30);
    expect(prefs.getInt('user_daily_goal'), 40);
    expect(h.adapter.requests, hasLength(1));
    owner = activityOtherOwner;
    container.invalidate(currentAccountIdProvider);
    expect(container.read(userPreferencesProvider).dailyGoal, 30);
    expect(container.read(userPreferencesProvider).dailyGoalConfirmed, isTrue);
    h.expectAuthPreserved();
  });

  test('p6 activity journal survives STOP and provider restart with one ACK',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final h = _ClientHarness();
    addTearDown(h.dispose);
    final repository =
        ApiLessonStudyActivityRepository(h.client.dio, () => activityOwner);
    addTearDown(repository.dispose);
    final store = PreferencesLessonCheckpointStore(prefs);
    final draft = activityDraft();
    await store.writeCheckpointAndActivities(activityOwner, activityLesson,
        '{"version":1}', draft.attemptId, [draft]);
    final refresh = _RefreshSpy();
    ProviderContainer createContainer() => ProviderContainer(overrides: [
          currentAccountIdProvider.overrideWithValue(activityOwner),
          currentAccountReaderProvider.overrideWithValue(() => activityOwner),
          sharedPreferencesProvider.overrideWithValue(prefs),
          lessonCheckpointStoreProvider.overrideWithValue(store),
          lessonStudyActivityRepositoryProvider.overrideWithValue(repository),
          studyActivityRefreshProvider.overrideWithValue(refresh),
        ]);
    Future<void> sync(ProviderContainer container) async {
      await container.read(lessonActivitySyncProvider.notifier).sync();
      await activityFlush();
    }

    final first = createContainer();
    await sync(first);
    expect(first.read(lessonActivitySyncProvider).pendingCount, 1);
    expect(first.read(lessonActivitySyncProvider).error, isNotNull);
    expect(refresh.calls, 0);
    final saved = (await store.pendingActivities(activityOwner)).single;
    expect(saved.attempted, isTrue);
    expect(saved.request.toJson(), draft.toJson());
    first.dispose();

    final cold = createContainer();
    addTearDown(cold.dispose);
    await sync(cold);
    expect(cold.read(lessonActivitySyncProvider).pendingCount, 1);
    expect(h.adapter.requests.map((request) => request['method']),
        ['POST', 'GET', 'POST']);
    expect(
        (await store.pendingActivities(activityOwner)).single.request.toJson(),
        draft.toJson());
    h.adapter.paused = false;
    await sync(cold);
    expect(h.adapter.requests.map((request) => request['method']),
        ['POST', 'GET', 'POST', 'GET', 'POST']);
    final posts =
        h.adapter.requests.where((request) => request['method'] == 'POST');
    expect(
        posts.map((request) => request['body']), everyElement(draft.toJson()));
    expect(await store.pendingActivities(activityOwner), isEmpty);
    expect(h.adapter.activities, hasLength(1));
    expect(refresh.calls, 1);
    await sync(cold);
    expect(h.adapter.requests, hasLength(5));
    expect(refresh.calls, 1);
    h.expectAuthPreserved();
  });
}

class _AuthStore implements AuthSessionStore {
  int refreshes = 0;
  int signOuts = 0;
  @override
  String? get currentAccessToken => 'local-fixture-token';
  @override
  Future<String?> refreshAccessToken() async {
    refreshes++;
    return currentAccessToken;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

class _ClientHarness {
  _ClientHarness() {
    refresh = AuthRefreshClient(dio: Dio()..httpClientAdapter = adapter);
    client = AppHttpClient(
        authSessionManager: AuthSessionManager(store: auth),
        authRefreshClient: refresh);
    client.dio.httpClientAdapter = adapter;
  }
  final auth = _AuthStore();
  final adapter = _StopTransport();
  late final AuthRefreshClient refresh;
  late final AppHttpClient client;
  void expectAuthPreserved() {
    expect(auth.refreshes, 0);
    expect(auth.signOuts, 0);
    expect(auth.currentAccessToken, 'local-fixture-token');
  }

  void dispose() {
    client.close(force: true);
    refresh.close(force: true);
  }
}

class _RefreshSpy extends Fake implements StudyActivityRefresh {
  int calls = 0;
  @override
  void refresh() => calls++;
}

class _StopTransport implements HttpClientAdapter {
  bool paused = true;
  final requests = <Map<String, dynamic>>[];
  final activities = <String, Map<String, dynamic>>{};
  final submissions = <String, Map<String, dynamic>>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add({
      'path': options.path,
      'method': options.method,
      'body':
          options.data == null ? null : jsonDecode(jsonEncode(options.data)),
    });
    var status = 200;
    Map<String, dynamic> body = {};
    if (options.method == 'GET') {
      final receipt = activities[options.path.split('/').last];
      body = receipt ?? {'detail': 'Not found'};
      status = receipt == null ? 404 : 200;
    } else if (paused) {
      status = 503;
      body = {'detail': _maintenance};
    } else {
      final data = options.data as Map<String, dynamic>;
      if (options.path.endsWith('/study-activities')) {
        final id = data['activityId'] as String;
        body = activities.putIfAbsent(
            id,
            () => {
                  'activityId': id,
                  'processedAt': '2026-11-03T01:00:00Z',
                  'studyDate': '2026-11-03',
                });
      } else if (options.path.endsWith('/submissions')) {
        final id = data['submissionId'] as String;
        body = submissions.putIfAbsent(
            id,
            () => {
                  'submissionId': id,
                  'processedAt': '2026-11-03T01:00:00Z',
                  'result': {
                    'scoreCorrect': 1,
                    'scoreTotal': 1,
                    'results': [],
                    'status': 'COMPLETED',
                    'srsItemsRegistered': 1,
                  },
                });
      }
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      'retry-after': ['60'],
      'cache-control': ['private, no-store'],
    });
  }

  @override
  void close({bool force = false}) {}
}

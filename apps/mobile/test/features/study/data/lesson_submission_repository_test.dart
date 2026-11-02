import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/auth_session_manager.dart';
import 'package:harukoto_mobile/core/network/auth_interceptor.dart';
import 'package:harukoto_mobile/core/network/network_base.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_submission.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Object? body;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

class _AuthStore implements AuthSessionStore {
  int refreshes = 0;
  int signOuts = 0;
  @override
  String? get currentAccessToken => 'local-fixture-token';
  @override
  Future<String?> refreshAccessToken() async {
    refreshes++;
    return 'other-account-fixture-token';
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

void main() {
  late Dio dio;
  late _Adapter adapter;
  late ApiStudyRepository repository;
  late LessonSubmissionDraft draft;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:59999/api/v1'));
    adapter = _Adapter();
    dio.httpClientAdapter = adapter;
    repository = ApiStudyRepository(dio);
    draft = LessonSubmissionDraft.create(owner: 'owner-fixture', answers: [
      {
        'order': 2,
        'submittedOrder': ['私', 'は'],
        'responseMs': 981
      }
    ]);
    adapter.body = {
      'submissionId': draft.submissionId,
      'processedAt': '2026-11-02T01:00:00Z',
      'result': {
        'scoreCorrect': 1,
        'scoreTotal': 1,
        'results': [],
        'status': 'COMPLETED',
        'srsItemsRegistered': 2
      }
    };
  });
  tearDown(() => dio.close());

  test(
      'new paths preserve frozen body/owner query and disable both retry channels',
      () async {
    final receipt = await repository.submitLessonIdempotent('lesson', draft);
    expect(receipt.submissionId, draft.submissionId);
    await repository.fetchLessonSubmission(
        'lesson', draft.submissionId, draft.owner);
    expect(adapter.requests.map((r) => r.path), [
      '/lessons/lesson/submissions',
      '/lessons/lesson/submissions/${draft.submissionId}'
    ]);
    expect(adapter.requests.first.data, draft.toJson());
    expect(
        adapter.requests.last.queryParameters, {'expectedUserId': draft.owner});
    for (final request in adapter.requests) {
      expect(request.extra[RequestMetadata.skipAuthRefresh], isTrue);
      expect(request.extra[RequestMetadata.skipNetworkRetry], isTrue);
    }
  });

  for (final status in [403, 404, 405, 409, 503]) {
    test(
        'POST $status retains contextual failure and never falls back to legacy',
        () async {
      adapter.status = status;
      adapter.body = {'detail': 'untrusted provider diagnostic'};
      await expectLater(
          repository.submitLessonIdempotent('lesson', draft),
          throwsA(isA<LessonSubmissionException>()
              .having((e) => e.statusCode, 'status', status)
              .having((e) => e.userMessage, 'safe message',
                  isNot(contains('untrusted')))));
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, endsWith('/submissions'));
    });
  }

  test('GET404 is only absence and makes no POST', () async {
    adapter.status = 404;
    expect(
        await repository.fetchLessonSubmission(
            'lesson', draft.submissionId, draft.owner),
        isNull);
    expect(adapter.requests.single.method, 'GET');
  });

  test(
      '401 on receipt routes does not refresh into another account or sign out',
      () async {
    final auth = _AuthStore();
    var replays = 0;
    dio.interceptors.add(AuthInterceptor(
        authSessionManager: AuthSessionManager(store: auth),
        replayRequest: (_) async {
          replays++;
          throw StateError('must not replay');
        }));
    adapter.status = 401;
    adapter.body = {'detail': 'expired'};
    await expectLater(repository.submitLessonIdempotent('lesson', draft),
        throwsA(isA<LessonSubmissionException>()));
    await expectLater(
        repository.fetchLessonSubmission(
            'lesson', draft.submissionId, draft.owner),
        throwsA(isA<LessonSubmissionException>()));
    expect(auth.refreshes, 0);
    expect(auth.signOuts, 0);
    expect(replays, 0);
    expect(adapter.requests, hasLength(2));
  });

  test(
      'malformed or unrelated receipt is never converted to zero score success',
      () async {
    adapter.body = {
      'submissionId': draft.submissionId,
      'processedAt': '2026-11-02T01:00:00Z',
      'result': {}
    };
    await expectLater(repository.submitLessonIdempotent('lesson', draft),
        throwsFormatException);
    adapter.body = {
      'submissionId':
          LessonSubmissionDraft.create(owner: draft.owner, answers: [])
              .submissionId,
      'processedAt': '2026-11-02T01:00:00Z',
      'result': {
        'scoreCorrect': 0,
        'scoreTotal': 0,
        'results': [],
        'status': 'COMPLETED',
        'srsItemsRegistered': 0
      }
    };
    await expectLater(repository.submitLessonIdempotent('lesson', draft),
        throwsFormatException);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/auth_session_manager.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/network/app_http_client.dart';
import 'package:harukoto_mobile/core/network/auth_refresh_client.dart';
import 'package:harukoto_mobile/core/network/network_base.dart';
import 'package:harukoto_mobile/features/kana/data/kana_repository.dart';

enum _Write { progress, start, answer, quiz, stage }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final write in _Write.values) {
    test('${write.name}: 401 after account switch never refreshes or replays',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.transport.status = 401;
      h.transport.gate = Completer<void>();

      final pending = _perform(h.repository, write);
      final failed = expectLater(
        pending,
        throwsA(isA<DioException>()
            .having((error) => error.response?.statusCode, 'statusCode', 401)),
      );
      await h.transport.arrived.future;
      h.auth.owner = 'learner-b';
      h.transport.gate!.complete();
      await failed;

      expect(h.transport.requests, hasLength(1));
      expect(h.transport.requests.single['authorization'],
          'Bearer fixture-learner-a');
      expect(h.transport.requests.single['skipAuthRefresh'], isTrue);
      expect(h.transport.requests.single['skipNetworkRetry'], isTrue);
      h.expectNoAuthMutation();
      expect(h.auth.owner, 'learner-b');
    });

    test('${write.name}: owner switch before dispatch sends no request',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.switchBeforeGuard = true;

      await expectLater(
        _perform(h.repository, write),
        throwsA(isA<DioException>()
            .having((error) => error.type, 'type', DioExceptionType.cancel)),
      );

      expect(h.transport.requests, isEmpty);
      h.expectNoAuthMutation();
    });

    test('${write.name}: signed-out owner sends no request', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.auth.owner = null;

      await expectLater(
        _perform(h.repository, write),
        throwsA(isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)),
      );

      expect(h.transport.requests, isEmpty);
      h.expectNoAuthMutation();
    });

    // This proves transport field stability only. In particular, start and
    // progress have no idempotency contract, and this does not make them safe
    // to replay after a lost acknowledgement.
    test('${write.name}: explicit invocations retain fields, not idempotency',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.transport.status = 503;

      await expectLater(
        _perform(h.repository, write),
        throwsA(isA<DioException>()
            .having((error) => error.response?.statusCode, 'statusCode', 503)),
      );
      expect(h.transport.requests, hasLength(1));
      h.expectNoAuthMutation();

      h.transport.status = 200;
      await _perform(h.repository, write);
      expect(h.transport.requests, hasLength(2));
      expect(h.transport.requests.first, h.transport.requests.last);
      h.expectNoAuthMutation();
    });
  }

  test('unrelated GET retains normal token refresh and replay behavior',
      () async {
    final h = _Harness();
    addTearDown(h.dispose);
    h.transport.statuses.addAll([401, 200]);

    final response = await h.client.dio.get<dynamic>('/read-only-fixture');

    expect(response.statusCode, 200);
    expect(h.transport.requests, hasLength(2));
    expect(h.auth.refreshes, 1);
    expect(h.auth.signOuts, 0);
    expect(h.transport.requests.first['skipAuthRefresh'], isNull);
    expect(h.transport.requests.last['authorization'],
        'Bearer refreshed-learner-a');
  });

  for (final invalid in [
    (name: 'answer absent', write: _Write.answer, body: <String, dynamic>{}),
    (
      name: 'answer blank option',
      write: _Write.answer,
      body: <String, dynamic>{'isCorrect': false, 'correctOptionId': ' '}
    ),
    (
      name: 'stage not acknowledged',
      write: _Write.stage,
      body: <String, dynamic>{'success': false}
    ),
    (name: 'completion absent', write: _Write.quiz, body: <String, dynamic>{}),
    (
      name: 'completion score invalid',
      write: _Write.quiz,
      body: <String, dynamic>{
        'accuracy': 101,
        'xpEarned': 0,
        'currentXp': 0,
        'xpForNext': 100,
        'level': 1
      }
    ),
  ]) {
    test('${invalid.name}: HTTP 200 is not accepted as a saved ACK', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.transport.responseBody = invalid.body;

      await expectLater(_perform(h.repository, invalid.write),
          throwsA(isA<FormatException>()));

      expect(h.transport.requests, hasLength(1));
      h.expectNoAuthMutation();
    });
  }

  for (final xp in [0, 27]) {
    test('valid completion with $xp XP remains valid', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.transport.responseBody = {
        'accuracy': 0,
        'xpEarned': xp,
        'currentXp': xp,
        'xpForNext': 100,
        'level': 1,
        'events': [],
      };

      final result =
          await h.repository.completeQuiz(sessionId: 'saved-session');

      expect(result.accuracy, 0);
      expect(result.xpEarned, xp);
      expect(h.transport.requests, hasLength(1));
      h.expectNoAuthMutation();
    });
  }
}

Future<Object?> _perform(KanaRepository repository, _Write write) =>
    switch (write) {
      _Write.progress =>
        repository.updateProgress(kanaId: 'kana-a', learned: true),
      _Write.start => repository.startQuiz(
          kanaType: 'HIRAGANA',
          stageNumber: 1,
          quizMode: 'recognition',
          count: 10),
      _Write.answer => repository.answerQuestion(
          sessionId: 'saved-session',
          questionId: 'question-2',
          selectedOptionId: 'option-b'),
      _Write.quiz => repository.completeQuiz(sessionId: 'saved-session'),
      _Write.stage =>
        repository.completeStage(stageId: 'stage-1', quizScore: 80),
    };

class _AuthStore implements AuthSessionStore {
  String? owner = 'learner-a';
  int refreshes = 0;
  int signOuts = 0;

  @override
  String? get currentAccessToken => owner == null ? null : 'fixture-$owner';

  @override
  Future<String?> refreshAccessToken() async {
    refreshes++;
    return owner == null ? null : 'refreshed-$owner';
  }

  @override
  Future<void> signOut() async => signOuts++;
}

class _Harness {
  _Harness() {
    refresh = AuthRefreshClient(dio: Dio()..httpClientAdapter = transport);
    client = AppHttpClient(
      authSessionManager: AuthSessionManager(store: auth),
      authRefreshClient: refresh,
    );
    client.dio.httpClientAdapter = transport;
    // A queued request can outlive the account captured when its button ran.
    // This executes before the repository's dispatch guard, after auth headers.
    client.dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) {
      if (switchBeforeGuard) auth.owner = 'learner-b';
      handler.next(options);
    }));
    repository = KanaRepository(client.dio, () => auth.owner);
  }

  final auth = _AuthStore();
  final transport = _Transport();
  bool switchBeforeGuard = false;
  late final AuthRefreshClient refresh;
  late final AppHttpClient client;
  late final KanaRepository repository;

  void expectNoAuthMutation() {
    expect(auth.refreshes, 0);
    expect(auth.signOuts, 0);
  }

  void dispose() {
    repository.dispose();
    client.close(force: true);
    refresh.close(force: true);
  }
}

class _Transport implements HttpClientAdapter {
  int status = 200;
  final statuses = <int>[];
  final requests = <Map<String, dynamic>>[];
  Map<String, dynamic>? responseBody;
  final arrived = Completer<void>();
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add({
      'method': options.method,
      'path': options.path,
      'body':
          options.data == null ? null : jsonDecode(jsonEncode(options.data)),
      'authorization': options.headers['Authorization'],
      'skipAuthRefresh': options.extra[RequestMetadata.skipAuthRefresh],
      'skipNetworkRetry': options.extra[RequestMetadata.skipNetworkRetry],
    });
    if (!arrived.isCompleted) arrived.complete();
    await gate?.future;
    final code = statuses.isEmpty ? status : statuses.removeAt(0);
    final body = responseBody ??
        switch (options.path) {
          '/kana/quiz/start' => {'sessionId': 'saved-session', 'questions': []},
          '/kana/quiz/answer' => {
              'isCorrect': false,
              'correctOptionId': 'option-a'
            },
          '/kana/quiz/complete' => {
              'accuracy': 80,
              'xpEarned': 12,
              'currentXp': 12,
              'xpForNext': 100,
              'level': 1,
              'events': []
            },
          _ => {'success': true},
        };
    return ResponseBody.fromString(jsonEncode(body), code, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

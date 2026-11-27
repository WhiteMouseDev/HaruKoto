import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/network/network_base.dart';
import 'package:harukoto_mobile/features/study/data/lesson_recognition_feedback_repository.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_recognition_feedback.dart';

const _owner = 'owner-fixture';
const _lesson = 'lesson-fixture';
const _version = '2026-11-27T02:00:00+00:00';
const _path = '/lessons/$_lesson/questions/2/feedback';
const _response = {
  'feedbackVersion': _version,
  'questionOrder': 2,
  'selectedAnswer': 'b',
  'correctAnswer': 'a',
  'isCorrect': false,
  'explanation': '  걱정이라는 뜻이에요.  ',
};

void main() {
  late Dio dio;
  late _Adapter adapter;
  late ApiLessonRecognitionFeedbackRepository repository;
  late String owner;

  setUp(() {
    owner = _owner;
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api/v1'));
    adapter = _Adapter();
    dio.httpClientAdapter = adapter;
    repository = ApiLessonRecognitionFeedbackRepository(dio, () => owner);
  });

  tearDown(() {
    repository.dispose();
    dio.close(force: true);
  });

  Future<LessonRecognitionFeedback> check() => repository.check(
        owner: _owner,
        lessonId: _lesson,
        questionOrder: 2,
        feedbackVersion: _version,
        selectedAnswer: 'b',
      );

  test('posts the identity-bound choice without an automatic replay', () async {
    final feedback = await check();
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, _path);
    expect(request.queryParameters, isEmpty);
    expect(request.data, {
      'expectedUserId': _owner,
      'feedbackVersion': _version,
      'selectedAnswer': 'b',
    });
    expect(request.extra[RequestMetadata.skipAuthRefresh], isTrue);
    expect(request.extra[RequestMetadata.skipNetworkRetry], isTrue);
    expect(feedback.toJson(), {
      ..._response,
      'explanation': '걱정이라는 뜻이에요.',
    });

    adapter.body = {
      ..._response,
      'correctAnswer': 'b',
      'isCorrect': true,
      'explanation': null,
    };
    final correct = await check();
    expect(correct.isCorrect, isTrue);
    expect(correct.explanation, isNull);
  });

  test('keeps the capability optional for older lesson detail responses', () {
    expect(
      LessonDetailModel.fromJson({'id': _lesson}).recognitionFeedbackVersion,
      isNull,
    );
    for (final version in [null, '', '  ', 1, 'a' * 65]) {
      expect(
        LessonDetailModel.fromJson({
          'id': _lesson,
          'recognitionFeedbackVersion': version,
        }).recognitionFeedbackVersion,
        isNull,
      );
    }
    expect(
      LessonDetailModel.fromJson({
        'id': _lesson,
        'recognitionFeedbackVersion': _version,
      }).recognitionFeedbackVersion,
      _version,
    );
  });

  test('rejects mismatched identity, grade, and malformed response shapes',
      () async {
    for (final body in [
      null,
      [_response],
      {..._response, 'feedbackVersion': 'other-version'},
      {..._response, 'questionOrder': 3},
      {..._response, 'questionOrder': '2'},
      {..._response, 'selectedAnswer': 'c'},
      {..._response, 'correctAnswer': ''},
      {..._response, 'isCorrect': 'false'},
      {..._response, 'isCorrect': true},
      {..._response, 'explanation': 5},
    ]) {
      adapter.body = body;
      await expectLater(check(), throwsFormatException);
    }
  });

  test('failed checks retain status and never fall back to a different route',
      () async {
    for (final status in [400, 401, 403, 404, 405, 409, 422, 503]) {
      adapter.status = status;
      adapter.body = {'detail': 'failure fixture'};
      await expectLater(
        check(),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', status)),
      );
    }
    expect(adapter.requests, hasLength(8));
    expect(
        adapter.requests.map((request) => request.path), everyElement(_path));
  });

  test('a changed account before the call sends nothing', () async {
    owner = 'different-owner';
    await expectLater(check(), throwsA(isA<ApiException>()));
    expect(adapter.requests, isEmpty);
  });

  test('an account change during asynchronous request setup sends nothing',
      () async {
    repository.dispose();
    final intercepting = Completer<void>();
    final proceed = Completer<void>();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      intercepting.complete();
      await proceed.future;
      handler.next(options);
    }));
    repository = ApiLessonRecognitionFeedbackRepository(dio, () => owner);

    final failure = expectLater(check(), throwsA(isA<ApiException>()));
    await intercepting.future;
    owner = 'different-owner';
    proceed.complete();
    await failure;
    expect(adapter.requests, isEmpty);
  });

  test('a response that arrives after an account change is discarded',
      () async {
    final received = Completer<void>();
    final respond = Completer<void>();
    adapter.beforeRespond = () async {
      received.complete();
      await respond.future;
    };

    final failure = expectLater(check(), throwsA(isA<ApiException>()));
    await received.future;
    owner = 'different-owner';
    respond.complete();
    await failure;
    expect(adapter.requests.single.path, _path);
  });
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<void> Function()? beforeRespond;
  Object? body = _response;
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await beforeRespond?.call();
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

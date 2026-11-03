import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/network/network_base.dart';
import 'package:harukoto_mobile/features/study/data/lesson_study_activity_repository.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_study_activity.dart';

import '../fixtures/lesson_activity_fixture.dart';

void main() {
  late Dio dio;
  late _Adapter adapter;
  late ApiLessonStudyActivityRepository repository;
  String? owner = activityOwner;
  setUp(() {
    owner = activityOwner;
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api/v1'));
    adapter = _Adapter();
    dio.httpClientAdapter = adapter;
    repository = ApiLessonStudyActivityRepository(dio, () => owner);
  });
  tearDown(() {
    repository.dispose();
    dio.close(force: true);
  });

  test('POST sends only frozen contract and binds receipt to original ID/day',
      () async {
    final request = activityDraft();
    adapter.response = _receipt(request.activityId);
    final receipt = await repository.submit(activityLesson, request);
    expect(adapter.requests.single.path,
        '/lessons/$activityLesson/study-activities');
    expect(adapter.requests.single.data, request.toJson());
    expect(adapter.requests.single.extra[RequestMetadata.skipNetworkRetry],
        isTrue);
    expect(
        adapter.requests.single.extra[RequestMetadata.skipAuthRefresh], isTrue);
    expect(receipt.activityId, request.activityId);
    expect(receipt.studyDate, '2026-11-02');
  });

  test('GET 404 means unknown, never creates POST or another ID', () async {
    final request = activityDraft();
    adapter.status = 404;
    adapter.response = {'detail': '없음'};
    expect(
        await repository.lookup(
            activityLesson, request.activityId, activityOwner),
        isNull);
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.queryParameters,
        {'expectedUserId': activityOwner});
    expect(adapter.requests.single.path,
        '/lessons/$activityLesson/study-activities/${request.activityId}');
  });

  test(
      'wrong receipt identity, missing offset and inconsistent KST day are rejected',
      () async {
    final request = activityDraft();
    for (final response in [
      _receipt(newLessonActivityId()),
      {..._receipt(request.activityId), 'processedAt': '2026-11-02T06:00:00'},
      {..._receipt(request.activityId), 'studyDate': '2026-11-03'},
    ]) {
      adapter.response = response;
      await expectLater(
          repository.submit(activityLesson, request), throwsFormatException);
    }
  });

  test('wrong current account sends nothing', () async {
    owner = activityOtherOwner;
    await expectLater(repository.submit(activityLesson, activityDraft()),
        throwsA(isA<ApiException>()));
    expect(adapter.requests, isEmpty);
  });

  test(
      'account switch while an earlier interceptor awaits is blocked before transport',
      () async {
    repository.dispose();
    final gate = Completer<void>();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      await gate.future;
      handler.next(options);
    }));
    repository = ApiLessonStudyActivityRepository(dio, () => owner);
    final sending = repository.submit(activityLesson, activityDraft());
    final failure = expectLater(sending, throwsA(isA<DioException>()));
    await activityFlush();
    owner = activityOtherOwner;
    gate.complete();
    await failure;
    expect(adapter.requests, isEmpty);
  });

  test('nullable or malformed optional capability preserves old lesson parser',
      () {
    for (final value in [null, 'not-a-version', 5]) {
      final detail = LessonDetailModel.fromJson(
          {'id': activityLesson, 'activityContentVersion': value});
      expect(detail.activityContentVersion, isNull);
      expect(detail.id, activityLesson);
    }
    expect(
        LessonDetailModel.fromJson({
          'id': activityLesson,
          'activityContentVersion': activityVersion
        }).activityContentVersion,
        activityVersion);
  });

  test('backend string and token limits accept their exact Unicode bounds', () {
    final recognition = activityDraft(answer: {
      'questionOrder': 1,
      'selectedAnswer': '𠮷' * 4096,
    });
    expect((recognition.answer['selectedAnswer'] as String).runes.length, 4096);
    final reorder = activityDraft(kind: 'SENTENCE_REORDER', answer: {
      'questionOrder': 1,
      'submittedOrder': ['𠮷' * 4096, ...List.filled(255, '水')],
    });
    expect(reorder.answer['submittedOrder'], hasLength(256));
  });
}

Map<String, dynamic> _receipt(String id) => {
      'activityId': id,
      'processedAt': '2026-11-02T06:00:00.123Z',
      'studyDate': '2026-11-02'
    };

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, dynamic> response = {};
  int status = 200;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(response), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

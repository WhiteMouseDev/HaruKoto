import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_base.dart';
import '../../../core/providers/dio_provider.dart';
import '../domain/lesson_study_activity.dart';

abstract class LessonStudyActivityRepository {
  Future<LessonStudyActivityReceipt> submit(
      String lessonId, LessonStudyActivityDraft request,
      {CancelToken? cancelToken});
  Future<LessonStudyActivityReceipt?> lookup(
      String lessonId, String activityId, String owner,
      {CancelToken? cancelToken});
}

class ApiLessonStudyActivityRepository
    implements LessonStudyActivityRepository {
  ApiLessonStudyActivityRepository(this._dio, this._currentOwner) {
    _guard = InterceptorsWrapper(onRequest: (options, handler) {
      final expected = options.extra[_ownerKey];
      if (expected != null && expected != _currentOwner()) {
        handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: const ApiException(message: '답변한 계정으로 로그인한 뒤 다시 확인해 주세요.')));
        return;
      }
      handler.next(options);
    });
    _dio.interceptors.add(_guard);
  }

  final Dio _dio;
  final String? Function() _currentOwner;
  late final Interceptor _guard;
  static const _ownerKey = '_lessonActivityExpectedOwner';

  void dispose() => _dio.interceptors.remove(_guard);

  Options _options(String owner) => Options(extra: {
        _ownerKey: owner,
        // This durable protocol owns retries. Never let a delayed network/auth
        // replay bypass the account guard using a different current session.
        RequestMetadata.skipNetworkRetry: true,
        RequestMetadata.skipAuthRefresh: true,
      });

  void _assertOwner(String owner) {
    if (_currentOwner() != owner) {
      throw const ApiException(
          message: '답변한 계정으로 로그인한 뒤 다시 확인해 주세요.', statusCode: 403);
    }
  }

  @override
  Future<LessonStudyActivityReceipt> submit(
      String lessonId, LessonStudyActivityDraft request,
      {CancelToken? cancelToken}) async {
    _assertOwner(request.owner);
    final response = await _dio.post<Map<String, dynamic>>(
      '/lessons/$lessonId/study-activities',
      data: request.toJson(),
      options: _options(request.owner),
      cancelToken: cancelToken,
    );
    _assertOwner(request.owner);
    return _receipt(response.data, request.activityId);
  }

  @override
  Future<LessonStudyActivityReceipt?> lookup(
      String lessonId, String activityId, String owner,
      {CancelToken? cancelToken}) async {
    _assertOwner(owner);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lessons/$lessonId/study-activities/$activityId',
        queryParameters: {'expectedUserId': owner},
        options: _options(owner),
        cancelToken: cancelToken,
      );
      _assertOwner(owner);
      return _receipt(response.data, activityId);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  LessonStudyActivityReceipt _receipt(Map<String, dynamic>? json, String id) {
    if (json == null) throw const FormatException('Missing activity receipt');
    final receipt = LessonStudyActivityReceipt.fromJson(json);
    if (receipt.activityId != id) {
      throw const FormatException('Activity receipt identity mismatch');
    }
    return receipt;
  }
}

final lessonStudyActivityRepositoryProvider =
    Provider<LessonStudyActivityRepository>((ref) {
  final repository = ApiLessonStudyActivityRepository(
      ref.watch(dioProvider), ref.watch(currentAccountReaderProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_base.dart';
import '../../../core/providers/dio_provider.dart';
import '../domain/lesson_recognition_feedback.dart';

abstract class LessonRecognitionFeedbackRepository {
  Future<LessonRecognitionFeedback> check({
    required String owner,
    required String lessonId,
    required int questionOrder,
    required String feedbackVersion,
    required String selectedAnswer,
  });
}

class ApiLessonRecognitionFeedbackRepository
    implements LessonRecognitionFeedbackRepository {
  ApiLessonRecognitionFeedbackRepository(this._dio, this._currentOwner) {
    _guard = InterceptorsWrapper(onRequest: (options, handler) {
      final expected = options.extra[_ownerKey];
      if (expected != null && expected != _currentOwner()) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: _ownerMismatch,
        ));
        return;
      }
      handler.next(options);
    });
    _dio.interceptors.add(_guard);
  }

  static const _ownerKey = '_lessonRecognitionFeedbackExpectedOwner';
  static const _ownerMismatch = ApiException(
    message: '답변한 계정으로 로그인한 뒤 다시 확인해 주세요.',
    statusCode: 403,
  );

  final Dio _dio;
  final String? Function() _currentOwner;
  late final Interceptor _guard;

  void dispose() => _dio.interceptors.remove(_guard);

  void _assertOwner(String owner) {
    if (_currentOwner() != owner) throw _ownerMismatch;
  }

  @override
  Future<LessonRecognitionFeedback> check({
    required String owner,
    required String lessonId,
    required int questionOrder,
    required String feedbackVersion,
    required String selectedAnswer,
  }) async {
    _assertOwner(owner);
    try {
      final response = await _dio.post<Object?>(
        '/lessons/$lessonId/questions/$questionOrder/feedback',
        data: {
          'expectedUserId': owner,
          'feedbackVersion': feedbackVersion,
          'selectedAnswer': selectedAnswer,
        },
        options: Options(extra: {
          _ownerKey: owner,
          // The request carries a specific owner's answer. Only retry it
          // explicitly through the lesson action after rechecking that owner.
          RequestMetadata.skipAuthRefresh: true,
          RequestMetadata.skipNetworkRetry: true,
        }),
      );
      _assertOwner(owner);
      final json = response.data;
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Missing lesson recognition feedback');
      }
      final feedback = LessonRecognitionFeedback.fromJson(json);
      if (feedback.feedbackVersion != feedbackVersion ||
          feedback.questionOrder != questionOrder ||
          feedback.selectedAnswer != selectedAnswer) {
        throw const FormatException('Lesson recognition feedback mismatch');
      }
      return feedback;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}

final lessonRecognitionFeedbackRepositoryProvider =
    Provider<LessonRecognitionFeedbackRepository>((ref) {
  final repository = ApiLessonRecognitionFeedbackRepository(
      ref.watch(dioProvider), ref.watch(currentAccountReaderProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

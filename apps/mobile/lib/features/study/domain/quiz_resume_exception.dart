import '../../../core/network/api_exception.dart';

/// A permanent, scoped failure to restore a quiz. It must not start a new quiz.
class QuizResumeException extends ApiException {
  const QuizResumeException({bool legacy = false})
      : super(
          message: legacy
              ? '이 퀴즈는 이전 형식으로 저장되어 이어서 불러올 수 없어요. 저장된 학습 기록은 유지됩니다.'
              : '퀴즈의 저장 정보를 안전하게 불러올 수 없어요. 저장된 학습 기록은 유지됩니다.',
          errorCode: 'QUIZ_RESUME_UNAVAILABLE',
        );

  @override
  String get userMessage => message;
}

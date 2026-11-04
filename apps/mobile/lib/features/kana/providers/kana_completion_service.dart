import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../home/providers/home_provider.dart';

import '../../home/providers/study_activity_refresh_provider.dart';
import '../data/models/kana_stage_model.dart';
import 'kana_provider.dart';

final kanaCompletionServiceProvider = Provider<KanaCompletionService>((ref) {
  return KanaCompletionService(ref);
});

class KanaCompletionService {
  const KanaCompletionService(this._ref);

  final Ref _ref;

  String _requireOwner() {
    final owner = _ref.read(currentAccountReaderProvider)();
    if (owner == null || _ref.read(currentAccountIdProvider) != owner) {
      throw const ApiException(message: '학습 계정을 확인할 수 없어요.', statusCode: 401);
    }
    return owner;
  }

  bool _isCurrent(String owner) =>
      _ref.mounted &&
      _ref.read(currentAccountReaderProvider)() == owner &&
      _ref.read(currentAccountIdProvider) == owner;

  Future<({bool isCorrect, String correctOptionId})> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
  }) async {
    final owner = _requireOwner();
    final result = await _ref.read(kanaRepositoryProvider).answerQuestion(
        sessionId: sessionId,
        questionId: questionId,
        selectedOptionId: selectedOptionId);
    if (_isCurrent(owner)) {
      _ref.read(studyActivityRefreshProvider).refresh();
      _ref.invalidate(profileProvider);
    }
    return result;
  }

  Future<CompleteQuizResponse> completeQuiz({required String sessionId}) async {
    final owner = _requireOwner();
    final result = await _ref
        .read(kanaRepositoryProvider)
        .completeQuiz(sessionId: sessionId);
    if (_isCurrent(owner)) _ref.read(studyActivityRefreshProvider).refresh();
    return result;
  }

  Future<void> completeStage({required String stageId, int? quizScore}) async {
    final owner = _requireOwner();
    await _ref
        .read(kanaRepositoryProvider)
        .completeStage(stageId: stageId, quizScore: quizScore);
    if (_isCurrent(owner)) _ref.read(studyActivityRefreshProvider).refresh();
  }
}

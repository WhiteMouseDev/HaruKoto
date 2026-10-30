import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/study_activity_refresh_provider.dart';
import '../data/models/kana_stage_model.dart';
import 'kana_provider.dart';

final kanaCompletionServiceProvider = Provider<KanaCompletionService>((ref) {
  return KanaCompletionService(ref);
});

class KanaCompletionService {
  const KanaCompletionService(this._ref);

  final Ref _ref;

  Future<CompleteQuizResponse> completeQuiz({required String sessionId}) async {
    final result = await _ref
        .read(kanaRepositoryProvider)
        .completeQuiz(sessionId: sessionId);
    if (_ref.mounted) _ref.read(studyActivityRefreshProvider).refresh();
    return result;
  }

  Future<void> completeStage({required String stageId, int? quizScore}) async {
    await _ref
        .read(kanaRepositoryProvider)
        .completeStage(stageId: stageId, quizScore: quizScore);
    if (_ref.mounted) _ref.read(studyActivityRefreshProvider).refresh();
  }
}

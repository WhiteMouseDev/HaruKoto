import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import 'chat_provider.dart';
import 'voice_call_session_provider.dart';

final callAnalysisServiceProvider = Provider<CallAnalysisService>((ref) {
  return CallAnalysisService(ref.watch(chatRepositoryProvider));
});

class CallAnalysisService {
  const CallAnalysisService(this._repository);

  final ChatRepository _repository;

  Future<LiveFeedbackResponse> analyze(VoiceCallAnalysisRequest request) async {
    final result = await _repository.sendLiveFeedback(
      transcript: request.transcript,
      durationSeconds: request.durationSeconds,
      characterId: request.characterId,
      scenarioId: request.scenarioId,
    );

    if (result.conversationId.isEmpty) {
      throw const CallAnalysisServiceException('분석 결과를 불러오지 못했습니다.');
    }

    return result;
  }
}

class CallAnalysisServiceException implements Exception {
  const CallAnalysisServiceException(this.message);

  final String message;
}

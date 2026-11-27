import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../home/providers/study_activity_refresh_provider.dart';

import '../data/chat_repository.dart';
import '../data/models/conversation_journey_episode.dart';
import 'chat_provider.dart';
import 'conversation_journey_progress_provider.dart';
import 'voice_call_session_provider.dart';

typedef SavedPracticeTracker = Future<void> Function()? Function(
    VoiceCallAnalysisRequest request);

final callAnalysisServiceProvider = Provider<CallAnalysisService>((ref) {
  return CallAnalysisService(
    ref.watch(chatRepositoryProvider),
    onCompleted: () {
      if (ref.mounted) {
        ref.invalidate(chatHistoryProvider);
        ref.invalidate(characterStatsProvider);
        ref.read(studyActivityRefreshProvider).refresh();
      }
    },
    captureSavedPractice: (request) {
      final scenarioId = request.scenarioId;
      if (scenarioId == null ||
          !isTokyoFirstDayScenario(scenarioId) ||
          !request.wasConnected ||
          !request.transcript.any((turn) =>
              turn['role'] == 'user' &&
              (turn['text']?.trim().isNotEmpty ?? false))) {
        return null;
      }
      final accountId = ref.read(currentAccountReaderProvider)();
      if (accountId == null) return null;
      final progress = ref.read(conversationJourneyProgressStoreProvider);
      return () async {
        final changed = await progress.markPracticed(
          accountId,
          scenarioId,
          isCurrentAccount: () =>
              ref.mounted &&
              ref.read(currentAccountReaderProvider)() == accountId,
        );
        if (changed && ref.mounted) {
          ref.invalidate(conversationJourneyProgressProvider(accountId));
        }
      };
    },
  );
});

class CallAnalysisService {
  const CallAnalysisService(
    this._repository, {
    this.onCompleted,
    this.captureSavedPractice,
  });

  final ChatRepository _repository;
  final void Function()? onCompleted;
  final SavedPracticeTracker? captureSavedPractice;

  Future<LiveFeedbackResponse> analyze(VoiceCallAnalysisRequest request) async {
    Future<void> Function()? markPracticeSaved;
    try {
      markPracticeSaved = captureSavedPractice?.call(request);
    } catch (error) {
      debugPrint('[CallAnalysis] Progress unavailable: ${error.runtimeType}');
    }
    final result = await _repository.sendLiveFeedback(
      transcript: request.transcript,
      durationSeconds: request.durationSeconds,
      analysisEnabled: request.analysisEnabled,
      conversationId: request.conversationId,
      characterId: request.characterId,
      scenarioId: request.scenarioId,
    );

    if (result.conversationId.isEmpty) {
      throw const CallAnalysisServiceException('분석 결과를 불러오지 못했습니다.');
    }

    onCompleted?.call();
    if (result.feedbackError != 'no_transcript') {
      try {
        await markPracticeSaved?.call();
      } catch (error) {
        debugPrint(
            '[CallAnalysis] Progress write failed: ${error.runtimeType}');
      }
    }
    return result;
  }
}

class CallAnalysisServiceException implements Exception {
  const CallAnalysisServiceException(this.message);

  final String message;
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/feedback_model.dart';
import 'chat_provider.dart';
import 'voice_call_session_provider.dart';

enum CallAnalysisStatus {
  idle,
  analyzing,
  completed,
  error,
}

class CallAnalysisState {
  const CallAnalysisState({
    this.status = CallAnalysisStatus.idle,
    this.statusMessage = '통화 내용을 분석하고 있어요...',
    this.progress = 0.0,
    this.currentStep = 1,
    this.conversationId,
    this.feedbackSummary,
    this.errorMessage,
  });

  static const _unset = Object();

  final CallAnalysisStatus status;
  final String statusMessage;
  final double progress;
  final int currentStep;
  final String? conversationId;
  final FeedbackSummary? feedbackSummary;
  final String? errorMessage;

  bool get isCompleted =>
      status == CallAnalysisStatus.completed &&
      conversationId != null &&
      conversationId!.isNotEmpty;

  CallAnalysisState copyWith({
    CallAnalysisStatus? status,
    String? statusMessage,
    double? progress,
    int? currentStep,
    Object? conversationId = _unset,
    Object? feedbackSummary = _unset,
    Object? errorMessage = _unset,
  }) {
    return CallAnalysisState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      conversationId: identical(conversationId, _unset)
          ? this.conversationId
          : conversationId as String?,
      feedbackSummary: identical(feedbackSummary, _unset)
          ? this.feedbackSummary
          : feedbackSummary as FeedbackSummary?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class CallAnalysisController extends Notifier<CallAnalysisState> {
  VoiceCallAnalysisRequest? _request;
  bool _disposed = false;
  int _generation = 0;

  @override
  CallAnalysisState build() {
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    return const CallAnalysisState();
  }

  Future<void> analyze(VoiceCallAnalysisRequest request) async {
    _request = request;
    final generation = ++_generation;

    state = const CallAnalysisState(
      status: CallAnalysisStatus.analyzing,
      statusMessage: '통화 내용을 분석하고 있어요...',
      progress: 0.0,
      currentStep: 1,
    );

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_isStale(generation)) return;

    state = state.copyWith(
      status: CallAnalysisStatus.analyzing,
      statusMessage: 'AI가 피드백을 생성하고 있어요...',
      progress: 0.3,
      currentStep: 2,
      conversationId: null,
      feedbackSummary: null,
      errorMessage: null,
    );

    try {
      final result = await ref.read(chatRepositoryProvider).sendLiveFeedback(
            transcript: request.transcript,
            durationSeconds: request.durationSeconds,
            characterId: request.characterId,
            scenarioId: request.scenarioId,
          );
      if (_isStale(generation)) return;

      if (result.conversationId.isEmpty) {
        state = state.copyWith(
          status: CallAnalysisStatus.error,
          statusMessage: '분석에 실패했습니다',
          progress: 0.0,
          errorMessage: '분석 결과를 불러오지 못했습니다.',
          conversationId: null,
          feedbackSummary: null,
        );
        return;
      }

      state = state.copyWith(
        status: CallAnalysisStatus.completed,
        statusMessage: '분석 완료!',
        progress: 1.0,
        currentStep: 3,
        conversationId: result.conversationId,
        feedbackSummary: result.feedbackSummary,
        errorMessage: null,
      );
    } catch (_) {
      if (_isStale(generation)) return;
      state = state.copyWith(
        status: CallAnalysisStatus.error,
        statusMessage: '분석에 실패했습니다',
        progress: 0.0,
        errorMessage: '분석에 실패했습니다',
        conversationId: null,
        feedbackSummary: null,
      );
    }
  }

  Future<void> retry() async {
    final request = _request;
    if (request == null) return;
    await analyze(request);
  }

  bool _isStale(int generation) => _disposed || generation != _generation;
}

final callAnalysisProvider =
    NotifierProvider<CallAnalysisController, CallAnalysisState>(
  CallAnalysisController.new,
);

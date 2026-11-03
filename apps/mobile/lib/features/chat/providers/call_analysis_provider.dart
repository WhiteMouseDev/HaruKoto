import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/feedback_model.dart';
import 'call_analysis_service.dart';
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
    this.recordSaved = false,
    this.feedbackSummary,
    this.feedbackError,
    this.errorMessage,
  });

  static const _unset = Object();

  final CallAnalysisStatus status;
  final String statusMessage;
  final double progress;
  final int currentStep;
  final String? conversationId;
  final bool recordSaved;
  final FeedbackSummary? feedbackSummary;
  final String? feedbackError;
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
    bool? recordSaved,
    Object? feedbackSummary = _unset,
    Object? feedbackError = _unset,
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
      recordSaved: recordSaved ?? this.recordSaved,
      feedbackSummary: identical(feedbackSummary, _unset)
          ? this.feedbackSummary
          : feedbackSummary as FeedbackSummary?,
      feedbackError: identical(feedbackError, _unset)
          ? this.feedbackError
          : feedbackError as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class CallAnalysisController extends Notifier<CallAnalysisState> {
  VoiceCallAnalysisRequest? _request;
  Object? _owner;
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

  Future<void> analyze(VoiceCallAnalysisRequest request,
      {Object? owner}) async {
    _request = request;
    _owner = owner;
    final generation = ++_generation;

    state = CallAnalysisState(
      status: CallAnalysisStatus.analyzing,
      conversationId: request.conversationId,
      recordSaved: request.recordSaved,
      statusMessage: '대화 기록을 저장하고 있어요...',
      progress: 0.0,
      currentStep: 1,
    );

    state = state.copyWith(
      status: CallAnalysisStatus.analyzing,
      statusMessage: request.analysisEnabled
          ? 'AI가 피드백을 생성하고 있어요...'
          : '대화 기록을 저장하고 있어요...',
      progress: 0.3,
      currentStep: 2,
      conversationId: request.conversationId,
      feedbackSummary: null,
      feedbackError: null,
      errorMessage: null,
    );

    try {
      final result =
          await ref.read(callAnalysisServiceProvider).analyze(request);
      if (_isStale(generation)) return;

      _request = request.withConversationId(result.conversationId);
      if (result.feedbackError == 'generation_failed') {
        state = state.copyWith(
          status: CallAnalysisStatus.error,
          statusMessage: '기록은 저장됐지만 피드백을 만들지 못했어요',
          conversationId: result.conversationId,
          recordSaved: true,
          feedbackError: result.feedbackError,
          errorMessage: '같은 대화의 피드백을 다시 요청할 수 있어요.',
        );
        return;
      }
      state = state.copyWith(
        status: CallAnalysisStatus.completed,
        statusMessage: request.analysisEnabled ? '분석 완료!' : '기록 저장 완료!',
        progress: 1.0,
        currentStep: 3,
        conversationId: result.conversationId,
        recordSaved: true,
        feedbackSummary: result.feedbackSummary,
        feedbackError: result.feedbackError ??
            (request.analysisEnabled ? null : 'analysis_skipped'),
        errorMessage: null,
      );
    } on CallAnalysisServiceException catch (error) {
      if (_isStale(generation)) return;
      state = state.copyWith(
        status: CallAnalysisStatus.error,
        statusMessage:
            !request.recordSaved ? '저장 상태를 확인하지 못했어요' : '피드백을 불러오지 못했어요',
        progress: 0.0,
        errorMessage: error.message,
        conversationId: request.conversationId,
        feedbackSummary: null,
        feedbackError: null,
      );
    } catch (_) {
      if (_isStale(generation)) return;
      state = state.copyWith(
        status: CallAnalysisStatus.error,
        statusMessage:
            !request.recordSaved ? '저장 상태를 확인하지 못했어요' : '피드백을 불러오지 못했어요',
        progress: 0.0,
        errorMessage: '분석에 실패했습니다',
        conversationId: request.conversationId,
        feedbackSummary: null,
        feedbackError: null,
      );
    }
  }

  void cancel(Object owner) {
    if (!identical(_owner, owner)) return;
    _generation++;
    _owner = null;
    _request = null;
  }

  Future<void> retry() async {
    final request = _request;
    if (request?.conversationId == null) return;
    await analyze(request!, owner: _owner);
  }

  bool _isStale(int generation) => _disposed || generation != _generation;
}

final callAnalysisProvider =
    NotifierProvider<CallAnalysisController, CallAnalysisState>(
  CallAnalysisController.new,
);

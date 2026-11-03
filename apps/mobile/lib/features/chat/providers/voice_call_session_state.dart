enum VoiceCallStatus {
  connecting,
  connected,
  ending,
  ended,
  error,
}

class VoiceCallSessionState {
  const VoiceCallSessionState({
    this.status = VoiceCallStatus.connecting,
    this.callDurationSeconds = 0,
    this.isMuted = false,
    this.microphoneInterrupted = false,
    this.resumingMicrophone = false,
    this.isAppActive = true,
    this.showSubtitle = true,
    this.currentAiText = '',
    this.receivingAiText = false,
    this.hasConnected = false,
    this.errorMessage,
    this.canRetryConnection = true,
  });

  static const _unset = Object();

  final VoiceCallStatus status;
  final int callDurationSeconds;
  final bool isMuted;
  final bool microphoneInterrupted;
  final bool resumingMicrophone;
  final bool isAppActive;
  final bool showSubtitle;
  final String currentAiText;
  final bool receivingAiText;
  final bool hasConnected;
  final String? errorMessage;
  final bool canRetryConnection;

  String get formattedDuration {
    final mins = (callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get statusLabel {
    switch (status) {
      case VoiceCallStatus.connecting:
        return callDurationSeconds > 0 ? '다시 연결하고 있어요' : '연결 중...';
      case VoiceCallStatus.ending:
        return '통화 종료 중...';
      case VoiceCallStatus.error:
        return '연결 실패';
      case VoiceCallStatus.connected:
        if (microphoneInterrupted) return '마이크 일시중지';
        if (receivingAiText) return '답변을 받고 있어요';
        return isMuted ? '마이크 꺼짐' : '연결됨 · 마이크 켜짐';
      case VoiceCallStatus.ended:
        return '통화 종료';
    }
  }

  bool get isConnected => status == VoiceCallStatus.connected;

  bool get canRetry =>
      status == VoiceCallStatus.error && canRetryConnection && !hasConnected;

  VoiceCallSessionState copyWith({
    VoiceCallStatus? status,
    int? callDurationSeconds,
    bool? isMuted,
    bool? microphoneInterrupted,
    bool? resumingMicrophone,
    bool? isAppActive,
    bool? showSubtitle,
    String? currentAiText,
    bool? receivingAiText,
    bool? hasConnected,
    Object? errorMessage = _unset,
    bool? canRetryConnection,
  }) {
    return VoiceCallSessionState(
      status: status ?? this.status,
      callDurationSeconds: callDurationSeconds ?? this.callDurationSeconds,
      isMuted: isMuted ?? this.isMuted,
      microphoneInterrupted:
          microphoneInterrupted ?? this.microphoneInterrupted,
      resumingMicrophone: resumingMicrophone ?? this.resumingMicrophone,
      isAppActive: isAppActive ?? this.isAppActive,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      currentAiText: currentAiText ?? this.currentAiText,
      receivingAiText: receivingAiText ?? this.receivingAiText,
      hasConnected: hasConnected ?? this.hasConnected,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      canRetryConnection: canRetryConnection ?? this.canRetryConnection,
    );
  }
}

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
    this.showSubtitle = true,
    this.currentAiText = '',
    this.errorMessage,
    this.canRetryConnection = true,
  });

  static const _unset = Object();

  final VoiceCallStatus status;
  final int callDurationSeconds;
  final bool isMuted;
  final bool showSubtitle;
  final String currentAiText;
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
        return '연결 중...';
      case VoiceCallStatus.ending:
        return '통화 종료 중...';
      case VoiceCallStatus.error:
        return '연결 실패';
      case VoiceCallStatus.connected:
        return formattedDuration;
      case VoiceCallStatus.ended:
        return '통화 종료';
    }
  }

  bool get isConnected => status == VoiceCallStatus.connected;

  bool get canRetry => status == VoiceCallStatus.error && canRetryConnection;

  VoiceCallSessionState copyWith({
    VoiceCallStatus? status,
    int? callDurationSeconds,
    bool? isMuted,
    bool? showSubtitle,
    String? currentAiText,
    Object? errorMessage = _unset,
    bool? canRetryConnection,
  }) {
    return VoiceCallSessionState(
      status: status ?? this.status,
      callDurationSeconds: callDurationSeconds ?? this.callDurationSeconds,
      isMuted: isMuted ?? this.isMuted,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      currentAiText: currentAiText ?? this.currentAiText,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      canRetryConnection: canRetryConnection ?? this.canRetryConnection,
    );
  }
}

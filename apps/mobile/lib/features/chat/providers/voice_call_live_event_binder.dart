import '../data/gemini_live_service.dart';

class VoiceCallLiveEventBinder {
  const VoiceCallLiveEventBinder({
    required this.service,
    required this.isActive,
    required this.onStateChange,
    required this.onAiTextDelta,
    required this.onTranscriptEntry,
    required this.onError,
  });

  final GeminiLiveService service;
  final bool Function() isActive;
  final void Function(GeminiLiveState state) onStateChange;
  final void Function(String text) onAiTextDelta;
  final void Function(TranscriptEntry entry) onTranscriptEntry;
  final void Function(String message) onError;

  void bind() {
    service.onStateChange = (liveState) {
      if (!isActive()) return;
      onStateChange(liveState);
    };

    service.onAiTextDelta = (text) {
      if (!isActive()) return;
      onAiTextDelta(text);
    };

    service.onTranscriptEntry = (entry) {
      if (!isActive()) return;
      onTranscriptEntry(entry);
    };

    service.onError = (message) {
      if (!isActive()) return;
      onError(message);
    };
  }
}

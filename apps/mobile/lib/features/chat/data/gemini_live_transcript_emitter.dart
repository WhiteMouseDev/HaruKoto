import 'gemini_live_message_handler.dart';
import 'gemini_live_transcript.dart';

class GeminiLiveTranscriptEmitter {
  const GeminiLiveTranscriptEmitter({
    required GeminiLiveMessageHandler messageHandler,
    required void Function(TranscriptEntry entry) emitEntry,
  })  : _messageHandler = messageHandler,
        _emitEntry = emitEntry;

  final GeminiLiveMessageHandler _messageHandler;
  final void Function(TranscriptEntry entry) _emitEntry;

  List<TranscriptEntry> get transcript {
    flush();
    return _messageHandler.transcript;
  }

  void emit(TranscriptEntry entry) {
    _emitEntry(entry);
  }

  void flush() {
    for (final entry in _messageHandler.flushPendingTranscript()) {
      _emitEntry(entry);
    }
  }
}

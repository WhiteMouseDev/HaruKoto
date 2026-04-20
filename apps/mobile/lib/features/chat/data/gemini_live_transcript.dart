/// Transcript entry for a single turn.
class TranscriptEntry {
  final String role; // 'user' or 'assistant'
  final String text;

  const TranscriptEntry({required this.role, required this.text});

  Map<String, String> toJson() => {'role': role, 'text': text};
}

class GeminiLiveTranscriptCollector {
  final List<TranscriptEntry> _transcript = [];
  final StringBuffer _currentUserText = StringBuffer();
  final StringBuffer _currentAiText = StringBuffer();

  List<TranscriptEntry> snapshot() => List.unmodifiable(_transcript);

  void appendUserText(String text) {
    if (text.isNotEmpty) {
      _currentUserText.write(text);
    }
  }

  void appendAiText(String text) {
    if (text.isNotEmpty) {
      _currentAiText.write(text);
    }
  }

  TranscriptEntry? flushUser() {
    if (_currentUserText.isEmpty) return null;

    final entry = TranscriptEntry(
      role: 'user',
      text: _currentUserText.toString().trim(),
    );
    _currentUserText.clear();

    if (entry.text.isEmpty) return null;
    _transcript.add(entry);
    return entry;
  }

  TranscriptEntry? flushAi() {
    if (_currentAiText.isEmpty) return null;

    final entry = TranscriptEntry(
      role: 'assistant',
      text: _currentAiText.toString().trim(),
    );
    _currentAiText.clear();

    if (entry.text.isEmpty) return null;
    _transcript.add(entry);
    return entry;
  }

  List<TranscriptEntry> flushAll() {
    return [
      if (flushUser() case final userEntry?) userEntry,
      if (flushAi() case final aiEntry?) aiEntry,
    ];
  }
}

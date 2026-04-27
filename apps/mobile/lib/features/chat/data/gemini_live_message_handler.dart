import 'gemini_live_transcript.dart';

enum GeminiLiveMessageActionType {
  setupComplete,
  updateResumptionHandle,
  reconnect,
  aiTextDelta,
  transcriptEntry,
  audioChunk,
  modelTurnComplete,
}

class GeminiLiveMessageAction {
  const GeminiLiveMessageAction._({
    required this.type,
    this.text,
    this.transcriptEntry,
  });

  const GeminiLiveMessageAction.setupComplete()
      : this._(type: GeminiLiveMessageActionType.setupComplete);

  const GeminiLiveMessageAction.updateResumptionHandle(String? handle)
      : this._(
          type: GeminiLiveMessageActionType.updateResumptionHandle,
          text: handle,
        );

  const GeminiLiveMessageAction.reconnect()
      : this._(type: GeminiLiveMessageActionType.reconnect);

  const GeminiLiveMessageAction.aiTextDelta(String text)
      : this._(type: GeminiLiveMessageActionType.aiTextDelta, text: text);

  const GeminiLiveMessageAction.transcriptEntry(TranscriptEntry entry)
      : this._(
          type: GeminiLiveMessageActionType.transcriptEntry,
          transcriptEntry: entry,
        );

  const GeminiLiveMessageAction.audioChunk(String base64Data)
      : this._(type: GeminiLiveMessageActionType.audioChunk, text: base64Data);

  const GeminiLiveMessageAction.modelTurnComplete()
      : this._(type: GeminiLiveMessageActionType.modelTurnComplete);

  final GeminiLiveMessageActionType type;
  final String? text;
  final TranscriptEntry? transcriptEntry;
}

class GeminiLiveMessageHandler {
  GeminiLiveMessageHandler({
    GeminiLiveTranscriptCollector? transcriptCollector,
  }) : _transcriptCollector =
            transcriptCollector ?? GeminiLiveTranscriptCollector();

  final GeminiLiveTranscriptCollector _transcriptCollector;

  List<TranscriptEntry> get transcript => _transcriptCollector.snapshot();

  List<TranscriptEntry> flushPendingTranscript() {
    return _transcriptCollector.flushAll();
  }

  List<GeminiLiveMessageAction> handle(Map<String, dynamic> msg) {
    if (msg.containsKey('setupComplete')) {
      return const [GeminiLiveMessageAction.setupComplete()];
    }

    if (msg.containsKey('sessionResumptionUpdate')) {
      final update = msg['sessionResumptionUpdate'] as Map<String, dynamic>?;
      return [
        GeminiLiveMessageAction.updateResumptionHandle(
          update?['newHandle'] as String?,
        ),
      ];
    }

    if (msg.containsKey('goAway')) {
      return const [GeminiLiveMessageAction.reconnect()];
    }

    final serverContent = msg['serverContent'] as Map<String, dynamic>?;
    if (serverContent == null) return const [];

    final actions = <GeminiLiveMessageAction>[];

    final inputTranscription =
        serverContent['inputTranscription'] as Map<String, dynamic>?;
    if (inputTranscription != null) {
      _transcriptCollector.appendUserText(
        inputTranscription['text'] as String? ?? '',
      );
    }

    final outputTranscription =
        serverContent['outputTranscription'] as Map<String, dynamic>?;
    if (outputTranscription != null) {
      final text = outputTranscription['text'] as String? ?? '';
      if (text.isNotEmpty) {
        _transcriptCollector.appendAiText(text);
        actions.add(GeminiLiveMessageAction.aiTextDelta(text));
      }
    }

    final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
    if (modelTurn != null) {
      final userEntry = _transcriptCollector.flushUser();
      if (userEntry != null) {
        actions.add(GeminiLiveMessageAction.transcriptEntry(userEntry));
      }

      final parts = modelTurn['parts'] as List<dynamic>? ?? [];
      for (final part in parts) {
        if (part is! Map<String, dynamic>) continue;
        final inlineData = part['inlineData'] as Map<String, dynamic>?;
        final base64Data = inlineData?['data'] as String?;
        if (base64Data != null && base64Data.isNotEmpty) {
          actions.add(GeminiLiveMessageAction.audioChunk(base64Data));
        }
      }
    }

    if (serverContent['turnComplete'] == true) {
      final aiEntry = _transcriptCollector.flushAi();
      if (aiEntry != null) {
        actions.add(GeminiLiveMessageAction.transcriptEntry(aiEntry));
      }
      actions.add(const GeminiLiveMessageAction.modelTurnComplete());
    }

    if (serverContent['interrupted'] == true) {
      final aiEntry = _transcriptCollector.flushAi();
      if (aiEntry != null) {
        actions.add(GeminiLiveMessageAction.transcriptEntry(aiEntry));
      }
    }

    return actions;
  }
}

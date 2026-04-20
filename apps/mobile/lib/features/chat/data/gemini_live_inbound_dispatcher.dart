import 'package:flutter/foundation.dart';

import 'gemini_live_message_handler.dart';
import 'gemini_live_protocol.dart';
import 'gemini_live_transcript.dart';

class GeminiLiveInboundDispatcher {
  const GeminiLiveInboundDispatcher({
    required GeminiLiveMessageHandler messageHandler,
    required bool Function() isActive,
    required void Function() onSetupComplete,
    required void Function(String? handle) onUpdateResumptionHandle,
    required void Function() onReconnect,
    required void Function(String text) onAiTextDelta,
    required void Function(TranscriptEntry entry) onTranscriptEntry,
    required void Function(String base64Data) onAudioChunk,
  })  : _messageHandler = messageHandler,
        _isActive = isActive,
        _onSetupComplete = onSetupComplete,
        _onUpdateResumptionHandle = onUpdateResumptionHandle,
        _onReconnect = onReconnect,
        _onAiTextDelta = onAiTextDelta,
        _onTranscriptEntry = onTranscriptEntry,
        _onAudioChunk = onAudioChunk;

  final GeminiLiveMessageHandler _messageHandler;
  final bool Function() _isActive;
  final void Function() _onSetupComplete;
  final void Function(String? handle) _onUpdateResumptionHandle;
  final void Function() _onReconnect;
  final void Function(String text) _onAiTextDelta;
  final void Function(TranscriptEntry entry) _onTranscriptEntry;
  final void Function(String base64Data) _onAudioChunk;

  void dispatch(dynamic raw) {
    if (!_isActive()) return;

    final msg = _parse(raw);
    if (msg == null) return;

    for (final action in _messageHandler.handle(msg)) {
      _apply(action);
    }
  }

  Map<String, dynamic>? _parse(dynamic raw) {
    try {
      final parsed = GeminiLiveProtocol.parseMessage(raw);
      if (parsed == null) {
        debugPrint('[GeminiLive] Unknown message type: ${raw.runtimeType}');
      }
      return parsed;
    } catch (e) {
      debugPrint('[GeminiLive] Failed to parse message: $e');
      return null;
    }
  }

  void _apply(GeminiLiveMessageAction action) {
    switch (action.type) {
      case GeminiLiveMessageActionType.setupComplete:
        _onSetupComplete();
      case GeminiLiveMessageActionType.updateResumptionHandle:
        _onUpdateResumptionHandle(action.text);
      case GeminiLiveMessageActionType.reconnect:
        _onReconnect();
      case GeminiLiveMessageActionType.aiTextDelta:
        final text = action.text;
        if (text != null) _onAiTextDelta(text);
      case GeminiLiveMessageActionType.transcriptEntry:
        final entry = action.transcriptEntry;
        if (entry != null) _onTranscriptEntry(entry);
      case GeminiLiveMessageActionType.audioChunk:
        final base64Data = action.text;
        if (base64Data != null) _onAudioChunk(base64Data);
    }
  }
}

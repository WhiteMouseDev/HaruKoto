import 'gemini_live_transcript.dart';

/// Callbacks for voice call UI.
typedef OnStateChange = void Function(GeminiLiveState state);
typedef OnAiTextDelta = void Function(String text);
typedef OnTranscriptEntry = void Function(TranscriptEntry entry);
typedef OnError = void Function(String message);

enum GeminiLiveState { connecting, connected, ending, ended, error }

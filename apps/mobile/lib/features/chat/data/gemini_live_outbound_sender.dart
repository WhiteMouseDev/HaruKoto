import 'package:flutter/foundation.dart';

import 'gemini_live_protocol.dart';
import 'gemini_live_transport.dart';

class GeminiLiveOutboundSender {
  const GeminiLiveOutboundSender({
    required this.transport,
  });

  final GeminiLiveTransport transport;

  void sendSetup({
    required String model,
    required String instruction,
    required String userNickname,
    required String jlptSection,
    required int silenceDurationMs,
    String? voiceName,
    String? resumptionHandle,
  }) {
    _safeSend(
      GeminiLiveProtocol.encodeSetup(
        GeminiLiveSetupConfig(
          model: model,
          voiceName: voiceName,
          instruction: instruction,
          userNickname: userNickname,
          jlptSection: jlptSection,
          silenceDurationMs: silenceDurationMs,
          resumptionHandle: resumptionHandle,
        ),
      ),
    );
  }

  void sendGreeting({
    required String? characterName,
    required String? scenarioGreeting,
  }) {
    _safeSend(
      GeminiLiveProtocol.encodeGreeting(
        characterName: characterName,
        scenarioGreeting: scenarioGreeting,
      ),
    );
  }

  void sendRealtimeAudio(Uint8List data) {
    _safeSend(GeminiLiveProtocol.encodeRealtimeAudio(data));
  }

  void _safeSend(String data) {
    try {
      transport.send(data);
    } catch (e) {
      debugPrint('[GeminiLive] sink.add failed: $e');
    }
  }
}

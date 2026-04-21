import 'gemini_live_outbound_sender.dart';
import 'gemini_live_prompt_builder.dart';

class GeminiLiveSetupSender {
  const GeminiLiveSetupSender({
    required GeminiLiveOutboundSender outboundSender,
    required GeminiLivePromptBuilder promptBuilder,
    required String model,
    required String userNickname,
    required int silenceDurationMs,
    String? voiceName,
  })  : _outboundSender = outboundSender,
        _promptBuilder = promptBuilder,
        _model = model,
        _userNickname = userNickname,
        _silenceDurationMs = silenceDurationMs,
        _voiceName = voiceName;

  final GeminiLiveOutboundSender _outboundSender;
  final GeminiLivePromptBuilder _promptBuilder;
  final String _model;
  final String _userNickname;
  final int _silenceDurationMs;
  final String? _voiceName;

  void send({String? resumptionHandle}) {
    _outboundSender.sendSetup(
      model: _model,
      voiceName: _voiceName,
      instruction: _promptBuilder.instruction,
      userNickname: _userNickname,
      jlptSection: _promptBuilder.jlptSection,
      silenceDurationMs: _silenceDurationMs,
      resumptionHandle: resumptionHandle,
    );
  }
}

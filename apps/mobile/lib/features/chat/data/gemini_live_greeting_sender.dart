import 'gemini_live_outbound_sender.dart';

class GeminiLiveGreetingSender {
  const GeminiLiveGreetingSender({
    required GeminiLiveOutboundSender outboundSender,
    String? characterName,
    String? scenarioGreeting,
  })  : _outboundSender = outboundSender,
        _characterName = characterName,
        _scenarioGreeting = scenarioGreeting;

  final GeminiLiveOutboundSender _outboundSender;
  final String? _characterName;
  final String? _scenarioGreeting;

  void send() {
    _outboundSender.sendGreeting(
      characterName: _characterName,
      scenarioGreeting: _scenarioGreeting,
    );
  }
}

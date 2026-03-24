import 'package:flutter/material.dart';

import 'voice_call_page.dart';

MaterialPageRoute<void> voiceCallRoute({
  String? scenarioId,
  String? characterId,
  String? characterName,
  String? avatarUrl,
}) {
  return MaterialPageRoute(
    builder: (_) => VoiceCallPage(
      scenarioId: scenarioId,
      characterId: characterId,
      characterName: characterName,
      avatarUrl: avatarUrl,
    ),
  );
}

void openVoiceCallPage(
  BuildContext context, {
  String? scenarioId,
  String? characterId,
  String? characterName,
  String? avatarUrl,
}) {
  Navigator.of(context, rootNavigator: true).push(
    voiceCallRoute(
      scenarioId: scenarioId,
      characterId: characterId,
      characterName: characterName,
      avatarUrl: avatarUrl,
    ),
  );
}

import 'package:flutter/material.dart';

import 'voice_call_page.dart';
import '../data/models/scenario_model.dart';

MaterialPageRoute<void> voiceCallRoute({
  String? scenarioId,
  ScenarioModel? scenario,
  String? characterId,
  String? characterName,
  String? avatarUrl,
}) {
  return MaterialPageRoute(
    builder: (_) => VoiceCallPage(
      scenarioId: scenarioId,
      scenario: scenario,
      characterId: characterId,
      characterName: characterName,
      avatarUrl: avatarUrl,
    ),
  );
}

void openVoiceCallPage(
  BuildContext context, {
  String? scenarioId,
  ScenarioModel? scenario,
  String? characterId,
  String? characterName,
  String? avatarUrl,
}) {
  Navigator.of(context, rootNavigator: true).push(
    voiceCallRoute(
      scenarioId: scenarioId,
      scenario: scenario,
      characterId: characterId,
      characterName: characterName,
      avatarUrl: avatarUrl,
    ),
  );
}

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../data/models/chat_message_model.dart';
import '../data/models/scenario_model.dart';

class ConversationLaunchData {
  const ConversationLaunchData({
    this.initialScenario,
    this.firstMessage,
  });

  final ScenarioModel? initialScenario;
  final FirstMessage? firstMessage;
}

void openConversationPage(
  BuildContext context, {
  required String conversationId,
  ScenarioModel? initialScenario,
  FirstMessage? firstMessage,
}) {
  context.go(
    '/chat/$conversationId',
    extra: ConversationLaunchData(
      initialScenario: initialScenario,
      firstMessage: firstMessage,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/models/conversation_model.dart';
import 'package:harukoto_mobile/features/chat/presentation/widgets/conversation_history_list.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';

void main() {
  testWidgets('history displays a stored UTC instant in device local time',
      (tester) async {
    // Backend emits aware UTC timestamps. Preserve the learner's wall-clock time
    // after serialization, including in the Asia/Seoul UAT test environment.
    final localStart = DateTime(2026, 11, 3, 14, 7);
    final storedStart = localStart.toUtc().toIso8601String();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          chatHistoryProvider.overrideWith((ref) async => [
                ConversationModel(
                  id: 'hotel-call',
                  type: 'VOICE',
                  createdAt: storedStart,
                  messageCount: 5,
                  scenario: const ConversationScenario(
                      title: '호텔 체크인',
                      titleJa: 'ホテル',
                      category: 'TRAVEL',
                      difficulty: 'BEGINNER'),
                )
              ]),
        ],
        child: const MaterialApp(
            home:
                Scaffold(body: ConversationHistoryList(filter: 'practice')))));
    await tester.pumpAndSettle();
    expect(find.text('11/3 14:07'), findsOneWidget);
    expect(find.text('호텔 체크인'), findsOneWidget);
    expect(find.text('5턴'), findsOneWidget);
  });
}

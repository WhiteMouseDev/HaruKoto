import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/models/conversation_journey_episode.dart';
import 'package:harukoto_mobile/features/chat/presentation/widgets/voice_call_help_sheet.dart';

void main() {
  testWidgets('mission hints reveal only the chosen goal, keyword and example',
      (tester) async {
    tester.view.physicalSize = const Size(320, 660);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hotel = tokyoFirstDayEpisodes[1];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 660),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: VoiceCallHelpSheet(
              caption: 'チェックインは15時からです。',
              isPractice: true,
              journeyEpisode: hotel,
            ),
          ),
        ),
      ),
    );

    expect(find.text(hotel.keywords[1]), findsNothing);
    expect(find.text(hotel.examples[1]), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, hotel.goals[1]));
    await tester.pumpAndSettle();
    expect(find.text('힌트 1/3 · 말할 뜻'), findsOneWidget);
    expect(find.text(hotel.keywords[1]), findsNothing);

    await tester.ensureVisible(find.text('키워드 보기'));
    await tester.tap(find.text('키워드 보기'));
    await tester.pumpAndSettle();
    expect(find.text(hotel.keywords[1]), findsOneWidget);
    expect(find.text(hotel.examples[1]), findsNothing);

    await tester.ensureVisible(find.text('예문 보기'));
    await tester.tap(find.text('예문 보기'));
    await tester.pumpAndSettle();
    expect(find.text(hotel.examples[1]), findsOneWidget);
    expect(find.text(hotel.meanings[1]), findsOneWidget);

    final firstGoal = find.widgetWithText(ChoiceChip, hotel.goals[0]);
    await tester.ensureVisible(firstGoal);
    await tester.tap(firstGoal);
    await tester.pumpAndSettle();
    expect(find.text('힌트 1/3 · 말할 뜻'), findsOneWidget);
    expect(find.text(hotel.examples[1]), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('other scenarios still show generic help actions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceCallHelpSheet(caption: '', isPractice: true),
        ),
      ),
    );

    expect(find.text('미션 힌트'), findsNothing);
    expect(find.text('다시 말해줘'), findsOneWidget);
    expect(find.text('답변 힌트 알려줘'), findsOneWidget);
  });
}

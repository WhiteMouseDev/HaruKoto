import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_special_mode_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  group('QuizSpecialModeContent', () {
    testWidgets('renders header and child content', (tester) async {
      await _pumpQuizSpecialModeContent(tester);

      expect(find.text('오답 복습'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('특수 퀴즈'), findsOneWidget);
    });

    testWidgets('forwards back action', (tester) async {
      var backRequested = false;

      await _pumpQuizSpecialModeContent(
        tester,
        onBack: () {
          backRequested = true;
        },
      );

      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pump();

      expect(backRequested, isTrue);
    });
  });
}

Future<void> _pumpQuizSpecialModeContent(
  WidgetTester tester, {
  VoidCallback? onBack,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: QuizSpecialModeContent(
        title: '오답 복습',
        count: '2/5',
        onBack: onBack ?? () {},
        child: const Center(
          child: Text('특수 퀴즈'),
        ),
      ),
    ),
  );
}

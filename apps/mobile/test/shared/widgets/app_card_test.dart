import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/constants/colors.dart';
import 'package:harukoto_mobile/shared/widgets/app_card.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('compact card keeps its surface and layout in $brightness',
        (tester) async {
      const cardKey = ValueKey('compact-surface');
      const contentKey = ValueKey('content');
      const darkSurface = AppColors.darkSecondary;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            body: Center(
              child: AppCard.compactSurface(
                key: cardKey,
                darkSurface: darkSurface,
                child: SizedBox(key: contentKey, width: 100, height: 40),
              ),
            ),
          ),
        ),
      );

      final card = find.byKey(cardKey);
      final surface = tester.widget<DecoratedBox>(
        find.descendant(of: card, matching: find.byType(DecoratedBox)),
      );
      final decoration = surface.decoration as BoxDecoration;
      expect(
          decoration.color,
          brightness == Brightness.light
              ? AppColors.redesignSurface
              : darkSurface);
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.border, isNull);
      expect(tester.getRect(card).deflate(16),
          tester.getRect(find.byKey(contentKey)));
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/constants/colors.dart';
import 'package:harukoto_mobile/shared/widgets/haru_button_styles.dart';

void main() {
  for (final size in HaruButtonSize.values) {
    testWidgets('$size primary keeps a 48dp hit target', (tester) async {
      var presses = 0;
      var enabled = true;
      const key = ValueKey('primary');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => FilledButton(
                  key: key,
                  onPressed: enabled
                      ? () => setState(() {
                            presses++;
                            enabled = false;
                          })
                      : null,
                  style: HaruButtonStyles.primary(context, size: size),
                  child: const Text('학습 시작'),
                ),
              ),
            ),
          ),
        ),
      );

      final button = find.byKey(key);
      final surface = find.descendant(
        of: button,
        matching: find.byType(Material),
      );
      final hitRect = tester.getRect(button);
      final paintRect = tester.getRect(surface);
      final compact = size == HaruButtonSize.compact;
      expect(hitRect.height, 48);
      expect(paintRect.height, compact ? 42 : 48);
      expect(hitRect.center, paintRect.center);
      final enabledSurface = tester.widget<Material>(surface);
      expect(enabledSurface.color, const Color(0xFFFF6A87));
      expect(enabledSurface.textStyle?.color, const Color(0xFFFFFFFF));
      final style = tester.widget<FilledButton>(button).style!;
      final text = style.textStyle!.resolve({})!;
      expect(text.fontWeight, compact ? FontWeight.w500 : FontWeight.w600);
      expect(style.padding!.resolve({})!.horizontal, 40);

      await tester.tapAt(Offset(hitRect.center.dx, hitRect.top + 1));
      expect(presses, 1);
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(surface).color, AppColors.redesignControl);
      expect(tester.widget<Material>(surface).textStyle?.color,
          const Color(0xFF999999));
    });
  }

  testWidgets(
    'an unselected pill keeps its own appearance and responds to taps',
    (tester) async {
      var selected = false;
      const key = ValueKey('pill');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => TextButton(
                  key: key,
                  style: HaruButtonStyles.pillTab(
                    context,
                    selected: selected,
                    minimumWidth: 84,
                  ),
                  onPressed: () => setState(() => selected = true),
                  child: const Text('문장배열'),
                ),
              ),
            ),
          ),
        ),
      );

      final button = find.byKey(key);
      final surface = find.descendant(
        of: button,
        matching: find.byType(Material),
      );
      expect(tester.getSize(button), const Size(84, 48));
      expect(tester.getSize(surface), const Size(84, 32));
      expect(
        tester.getCenter(find.text('문장배열')).dy,
        closeTo(tester.getCenter(surface).dy - 1, 0.001),
      );
      expect(tester.widget<Material>(surface).color, AppColors.redesignControl);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(surface).color, AppColors.redesignStrong);
    },
  );
}

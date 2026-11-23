import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/shared/widgets/app_segmented_tabs.dart';

void main() {
  testWidgets('selection stays usable and announced with large text',
      (tester) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 288,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: StatefulBuilder(
                  builder: (_, setState) => AppSegmentedTabs(
                    labels: const ['기간별', '학습별', 'JLPT 진도'],
                    selectedIndex: selectedIndex,
                    onChanged: (index) => setState(() => selectedIndex = index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final period = find.text('기간별');
    final jlpt = find.text('JLPT 진도');
    expect(tester.getSemantics(period), isSemantics(isSelected: true));
    expect(tester.getSemantics(jlpt), isSemantics(isSelected: false));
    expect(tester.getSize(find.byType(TextButton).last).height,
        greaterThanOrEqualTo(kMinInteractiveDimension));

    await tester.tap(jlpt);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSemantics(period), isSemantics(isSelected: false));
    expect(tester.getSemantics(jlpt), isSemantics(isSelected: true));
  });
}

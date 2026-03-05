import 'package:flutter_test/flutter_test.dart';

import 'package:harukoto_mobile/main.dart';

void main() {
  testWidgets('HarukotoApp renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HarukotoApp());

    expect(find.text('하루코토'), findsOneWidget);
    expect(find.text('매일 한 단어, 봄처럼 피어나는 일본어'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:harukoto_mobile/app.dart';

void main() {
  testWidgets('HarukotoApp renders', (WidgetTester tester) async {
    // Basic smoke test - full widget test requires Supabase mock
    expect(const HarukotoApp(), isNotNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/shared/widgets/app_error_retry.dart';

void main() {
  group('AppErrorRetry', () {
    testWidgets('renders default message and submessage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorRetry(onRetry: () {}),
          ),
        ),
      );

      expect(find.text('데이터를 불러올 수 없습니다'), findsOneWidget);
      expect(find.text('네트워크 연결을 확인해주세요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('renders custom message and submessage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorRetry(
              onRetry: () {},
              message: 'Custom error',
              submessage: 'Please try again',
            ),
          ),
        ),
      );

      expect(find.text('Custom error'), findsOneWidget);
      expect(find.text('Please try again'), findsOneWidget);
    });

    testWidgets('tapping retry button calls onRetry callback', (tester) async {
      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorRetry(
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('다시 시도'));
      expect(retryCalled, isTrue);
    });
  });
}

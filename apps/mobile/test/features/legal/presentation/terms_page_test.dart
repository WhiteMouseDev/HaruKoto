import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/connectivity_service.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/router/app_router.dart';
import 'package:harukoto_mobile/features/auth/providers/auth_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';
import 'package:harukoto_mobile/features/home/presentation/home_page.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/legal/presentation/privacy_page.dart';
import 'package:harukoto_mobile/features/legal/presentation/terms_page.dart';
import 'package:harukoto_mobile/features/my/data/models/profile_detail_model.dart';
import 'package:harukoto_mobile/features/my/presentation/my_page.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:harukoto_mobile/features/notifications/data/models/notification_model.dart';
import 'package:harukoto_mobile/features/notifications/providers/notification_provider.dart';
import 'package:harukoto_mobile/shared/widgets/bottom_nav.dart';
import 'package:harukoto_mobile/shared/widgets/business_info_footer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('terms remain scrollable at large text sizes and can close',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const TermsPage()),
                ),
                child: const Text('약관 열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('약관 열기'));
    await tester.pumpAndSettle();
    expect(find.text('이용약관'), findsOneWidget);
    expect(find.text('제1조 (목적)'), findsOneWidget);

    final addendum = find.text('본 약관은 2025년 1월 1일부터 시행합니다.');
    await tester.scrollUntilVisible(addendum, 350, maxScrolls: 60);
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byType(Scrollable));
    final addendumBounds = tester.getRect(addendum);
    expect(addendumBounds.top, greaterThanOrEqualTo(viewport.top));
    expect(addendumBounds.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(find.text('이용약관'), findsOneWidget);
    final footer = find.byType(BusinessInfoFooter);
    await tester.scrollUntilVisible(footer, 160);
    await tester.pumpAndSettle();
    expect(tester.getRect(footer).width, viewport.width);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('약관 열기'), findsOneWidget);
  });

  testWidgets('privacy title, tables and footer fit at large text sizes',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: PrivacyPage(onBack: () {}),
      ),
    );

    final appBar = tester.getRect(find.byType(AppBar));
    final title = tester.getRect(find.text('개인정보처리방침'));
    expect(title.height, greaterThan(56));
    expect(title.top, greaterThanOrEqualTo(appBar.top + 4));
    expect(title.bottom, lessThanOrEqualTo(appBar.bottom - 4));
    expect(find.text('시행일: 2025년 1월 1일'), findsOneWidget);

    final tableEntry = find.text('Supabase Inc.');
    await tester.scrollUntilVisible(tableEntry, 280);
    final table = find.ancestor(of: tableEntry, matching: find.byType(Table));
    expect(tester.getSize(table).width, lessThanOrEqualTo(280));

    final finalArticle = find.text('제10조 (권익침해 구제방법)');
    await tester.scrollUntilVisible(finalArticle, 280);
    expect(finalArticle.hitTestable(), findsOneWidget);

    final addendum = find.text('본 개인정보처리방침은 2025년 1월 1일부터 시행합니다.');
    await tester.scrollUntilVisible(addendum, 280);
    expect(addendum.hitTestable(), findsOneWidget);

    final footer = find.byType(BusinessInfoFooter);
    await tester.scrollUntilVisible(footer, 160);
    await tester.pumpAndSettle();
    expect(tester.getSize(footer).width, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legal entries and deep links keep back and tab navigation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scope = ProviderContainer(retry: (_, __) => null, overrides: [
      currentAccountIdProvider.overrideWithValue('test-account'),
      currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
      isAuthenticatedProvider.overrideWithValue(true),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      sharedPreferencesProvider.overrideWithValue(preferences),
      profileDetailProvider
          .overrideWith((ref) async => ProfileDetailModel.fromJson({
                'profile': {'id': 'test-account', 'nickname': 'Test'},
              })),
      dashboardProvider
          .overrideWith((ref) async => DashboardModel.fromJson({})),
      profileProvider.overrideWith((ref) async => const UserProfileModel(
            nickname: 'Test',
            dailyGoal: 10,
            showKana: false,
            jlptLevel: 'N5',
          )),
      missionsProvider.overrideWith((ref) async => []),
      notificationsProvider.overrideWith((ref) async =>
          const NotificationsResponse(notifications: [], unreadCount: 0)),
    ]);
    final router = scope.read(routerProvider);
    router.go('/legal/terms');

    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      final termsPage = find.byType(TermsPage);
      final navigation = find.byType(BottomNav);
      expect(termsPage, findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(tester.widget<BottomNav>(navigation).currentIndex, 4);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(MyPage), findsOneWidget);

      final termsEntry = find.text('이용약관');
      await tester.scrollUntilVisible(termsEntry, 280);
      await tester.pumpAndSettle();
      await tester.tap(termsEntry.hitTestable());
      await tester.pumpAndSettle();
      expect(termsPage, findsOneWidget);
      expect(router.canPop(), isTrue);
      expect(
          tester.widget<BottomNav>(navigation.hitTestable()).currentIndex, 4);

      await tester.tap(find.descendant(
        of: navigation.hitTestable(),
        matching: find.text('마이페이지'),
      ));
      await tester.pumpAndSettle();
      expect(termsPage, findsNothing);
      expect(termsEntry.hitTestable(), findsOneWidget);

      await tester.tap(termsEntry.hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: navigation.hitTestable(),
        matching: find.text('홈'),
      ));
      await tester.pumpAndSettle();
      expect(termsPage, findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.widget<BottomNav>(navigation).currentIndex, 0);

      router.go('/legal/privacy');
      await tester.pumpAndSettle();
      final privacyPage = find.byType(PrivacyPage);
      expect(privacyPage, findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(tester.widget<BottomNav>(navigation).currentIndex, 4);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(MyPage), findsOneWidget);

      final privacyEntry = find.text('개인정보 처리방침');
      await tester.scrollUntilVisible(privacyEntry, 280);
      await tester.pumpAndSettle();
      await tester.tap(privacyEntry.hitTestable());
      await tester.pumpAndSettle();
      expect(privacyPage, findsOneWidget);
      expect(router.canPop(), isTrue);
      expect(
          tester.widget<BottomNav>(navigation.hitTestable()).currentIndex, 4);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(privacyEntry.hitTestable(), findsOneWidget);

      await tester.tap(privacyEntry.hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: navigation.hitTestable(),
        matching: find.text('홈'),
      ));
      await tester.pumpAndSettle();
      expect(privacyPage, findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
    }
  });
}

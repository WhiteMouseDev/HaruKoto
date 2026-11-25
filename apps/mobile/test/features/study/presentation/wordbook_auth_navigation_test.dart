import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/connectivity_service.dart';
import 'package:harukoto_mobile/core/providers/dio_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/router/app_router.dart';
import 'package:harukoto_mobile/features/auth/data/auth_repository.dart';
import 'package:harukoto_mobile/features/auth/presentation/login_page.dart';
import 'package:harukoto_mobile/features/auth/providers/auth_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';
import 'package:harukoto_mobile/features/home/presentation/home_page.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/notifications/data/models/notification_model.dart';
import 'package:harukoto_mobile/features/notifications/providers/notification_provider.dart';
import 'package:harukoto_mobile/features/study/presentation/wordbook_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
      'home wordbook keeps its route after a transient auth error and redirects on sign-out',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final auth = _AuthRepository();
    var wordbookReads = 0;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      if (request.path == '/wordbook/' && ++wordbookReads == 1) {
        // The network layer has exhausted its refresh attempt. The SDK reports
        // the temporary failure without clearing its current session.
        auth.events.addError(AuthRetryableFetchException());
        handler.reject(DioException.badResponse(
          statusCode: 401,
          requestOptions: request,
          response: Response<void>(requestOptions: request, statusCode: 401),
        ));
        return;
      }
      handler.resolve(Response<Map<String, dynamic>>(
        requestOptions: request,
        data: const {},
        statusCode: 200,
      ));
    }));
    final scope = ProviderContainer(retry: (_, __) => null, overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      dioProvider.overrideWithValue(dio),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      sharedPreferencesProvider.overrideWithValue(preferences),
      dashboardProvider
          .overrideWith((ref) async => DashboardModel.fromJson({})),
      profileProvider.overrideWith((ref) async => const UserProfileModel(
            nickname: 'Test',
            dailyGoal: 10,
            showKana: false,
            jlptLevel: 'N5',
          )),
      missionsProvider.overrideWith((ref) async => []),
      notificationsProvider.overrideWith(
        (ref) async => const NotificationsResponse(
          notifications: [],
          unreadCount: 0,
        ),
      ),
    ]);

    try {
      scope.listen(authStateProvider, (_, __) {});
      auth.events.add(AuthState(AuthChangeEvent.initialSession, auth.session));
      expect(scope.read(isAuthenticatedProvider), isTrue);
      final router = scope.read(routerProvider);
      router.go('/home');
      await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: Consumer(
          builder: (context, ref, child) => MaterialApp.router(
            routerConfig: ref.watch(routerProvider),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      final shortcut = find.text('단어장');
      await tester.scrollUntilVisible(shortcut, 280);
      await tester.pumpAndSettle();
      await tester.tap(shortcut.hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(wordbookReads, 1);
      expect(auth.currentSession, isNotNull);
      expect(scope.read(authStateProvider).hasError, isTrue);
      expect(scope.read(isAuthenticatedProvider), isTrue);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(WordbookPage), findsOneWidget);
      expect(find.text('단어장을 불러올 수 없습니다.'), findsOneWidget);

      await tester.tap(find.text('다시 시도하기'));
      await tester.pumpAndSettle();
      expect(wordbookReads, 2);
      expect(find.text('단어장에 단어가 없어요.'), findsOneWidget);

      await auth.signOut();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(scope.read(isAuthenticatedProvider), isFalse);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(WordbookPage), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      dio.close(force: true);
      unawaited(auth.events.close());
    }
  });
}

class _AuthRepository extends Fake implements AuthRepository {
  final events = StreamController<AuthState>(sync: true);
  Session? session = Session(
    accessToken: 'fixture',
    tokenType: 'bearer',
    user: const User(
      id: 'test-account',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    ),
  );

  @override
  Stream<AuthState> get authStateChanges => events.stream;

  @override
  Session? get currentSession => session;

  @override
  bool get isAuthenticated => session != null;

  @override
  Future<void> signOut() async {
    session = null;
    events.add(const AuthState(AuthChangeEvent.signedOut, null));
  }
}

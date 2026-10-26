import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/core/network/connectivity_service.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_progress_refresh_provider.dart';
import 'package:harukoto_mobile/shared/widgets/bottom_nav.dart';
import 'package:harukoto_mobile/shared/widgets/main_shell.dart';

void main() {
  testWidgets('returning home and foreground refresh saved quiz progress',
      (tester) async {
    final refresh = _RefreshSpy();
    final container = ProviderContainer(overrides: [
      quizProgressRefreshProvider.overrideWithValue(refresh),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
    ]);
    final router = GoRouter(initialLocation: '/home', routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const Text('Home')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/study', builder: (_, __) => const Text('Study')),
          ]),
        ],
      ),
    ]);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      tester.widget<BottomNav>(find.byType(BottomNav)).onTap(1);
      await tester.pumpAndSettle();
      expect(refresh.calls, 0);
      tester.widget<BottomNav>(find.byType(BottomNav)).onTap(0);
      await tester.pumpAndSettle();
      expect(refresh.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(refresh.calls, 2);
    } finally {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
    }
  });
}

class _RefreshSpy extends Fake implements QuizProgressRefresh {
  int calls = 0;

  @override
  void refresh() => calls++;
}
